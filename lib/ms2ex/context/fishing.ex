defmodule Ms2ex.Context.Fishing do
  @moduledoc """
  Fishing, ported from the reference FishingManager.

  Preparing a rod finds the water tiles in front of the player, spawns the
  bobber guide object and hands the tiles to the client. Casting picks a fish
  from the map's fish boxes and arms a bite timer; catching rolls the size,
  updates the album and awards fishing mastery.
  """

  alias Ms2ex.Context
  alias Ms2ex.Managers
  alias Ms2ex.Managers.Character.Fishing
  alias Ms2ex.Managers.Character.Mastery
  alias Ms2ex.Packets
  alias Ms2ex.Schema
  alias Ms2ex.Storage
  alias Ms2ex.Types.Coord

  import Ms2ex.Net.SenderSession, only: [push: 2]

  @block_size 150
  @default_bore_duration 15_000
  @default_fight_probability 5000

  @doc "Casts the rod: validates it, finds reachable water and spawns the bobber."
  @spec prepare(Schema.Character.t(), integer()) :: :ok | {:error, atom()}
  def prepare(%Schema.Character{} = character, rod_uid) do
    with nil <- Fishing.session(character),
         {:ok, rod} <- rod_metadata(character, rod_uid),
         :ok <- check_rod_mastery(character, rod),
         {:ok, spot} <- Storage.Tables.Fish.spot(character.map_id),
         :ok <- check_spot_mastery(character, spot),
         [_ | _] = tiles <- reachable_tiles(character),
         {:ok, guide} <- spawn_guide(character, tiles) do
      fishing = %{
        rod_uid: rod_uid,
        rod: rod,
        spot: spot,
        tiles: Map.new(tiles, &{cell(&1.position), &1}),
        guide: guide,
        tile: nil,
        fish_id: nil,
        fight_game?: false
      }

      Managers.Character.call(character.id, {:start_fishing, fishing})

      push(character, Packets.Fishing.load_tiles(tiles, rod.reduce_time))
      Context.Field.broadcast(character, Packets.GuideObject.create(guide))
      push(character, Packets.Fishing.prepare(rod_uid))
      :ok
    else
      %{} -> {:error, :s_fishing_error_system_error}
      [] -> {:error, :s_fishing_error_notexist_fish}
      :error -> {:error, :s_fishing_error_notexist_fish}
      {:error, error} -> {:error, error}
    end
  end

  @doc "Drops the line on a tile and arms the bite timer."
  @spec start(Schema.Character.t(), map()) :: :ok | {:error, atom()}
  def start(%Schema.Character{} = character, position) do
    with %{} = fishing <- Fishing.session(character),
         %{} = tile <- Map.get(fishing.tiles, cell(position)),
         [_ | _] = fishes <- available_fishes(fishing.spot, tile.liquid_type) do
      fish = pick_weighted(fishes)
      {ticks, fight_game?} = bite_timer(fishing.rod, fish, auto_fishing?(character))

      Managers.Character.call(character.id, {:fishing_bite, tile, fish.id, fight_game?})
      push(character, Packets.Fishing.start(Ms2ex.sync_ticks() + ticks, fight_game?))
      :ok
    else
      nil -> {:error, :s_fishing_error_system_error}
      [] -> {:error, :s_fishing_error_notexist_fish}
      _ -> {:error, :s_fishing_error_system_error}
    end
  end

  @doc "Resolves the bite: a success lands the fish and the spot's loot."
  @spec catch_fish(Schema.Character.t(), boolean()) :: :ok | {:error, atom()}
  def catch_fish(%Schema.Character{} = character, success?) do
    with %{fish_id: fish_id} = fishing when not is_nil(fish_id) <- Fishing.session(character),
         {:ok, fish} <- Storage.Tables.Fish.fish(fish_id) do
      size = roll_size(fish)
      auto? = auto_fishing?(character)

      if success? do
        character
        |> land_fish(fish, size, auto?)
        |> catch_items(fishing.spot)
      else
        update_conditions(character, :fish_fail, fish.id)
        push(character, Packets.Fishing.catch_fish(fish.id, size, auto?))
        Managers.Character.call(character.id, :fishing_fail_minigame)
      end

      :ok
    else
      _ -> {:error, :s_fishing_error_system_error}
    end
  end

  @doc "Reels in: removes the bobber and clears the session."
  @spec stop(Schema.Character.t()) :: :ok
  def stop(%Schema.Character{} = character) do
    case Fishing.session(character) do
      nil ->
        :ok

      %{guide: guide} ->
        push(character, Packets.Fishing.stop())
        Context.Field.broadcast(character, Packets.GuideObject.remove(guide))
        Managers.Character.call(character.id, :stop_fishing)
        :ok
    end
  end

  @doc "The client lost the fight minigame; the bite stays but the game ends."
  def fail_minigame(%Schema.Character{} = character) do
    Managers.Character.call(character.id, :fishing_fail_minigame)
    :ok
  end

  # ---- validation ----

  defp rod_metadata(character, rod_uid) do
    with %Schema.Item{} = item <- Managers.Inventory.get(character, rod_uid),
         %{function_name: "FishingRod", function_param: rod_code}
         when is_integer(rod_code) <- Context.Items.load_metadata(item).metadata,
         {:ok, rod} <- Storage.Tables.FishingRods.lookup(rod_code) do
      {:ok, rod}
    else
      _ -> {:error, :s_fishing_error_invalid_item}
    end
  end

  defp check_rod_mastery(character, rod) do
    if Mastery.value(character, :fishing) >= rod.min_mastery do
      :ok
    else
      {:error, :s_fishing_error_fishingrod_mastery}
    end
  end

  defp check_spot_mastery(character, spot) do
    if Mastery.value(character, :fishing) >= spot.min_mastery do
      :ok
    else
      {:error, :s_fishing_error_lack_mastery}
    end
  end

  # ---- water tiles ----

  # the client only lets a player fish into the quadrant they face; the box
  # in front of them is scanned for surface water
  defp reachable_tiles(character) do
    surfaces = Storage.Maps.get_fluid_surfaces(character.map_id)

    case scan_box(character) do
      nil ->
        []

      {min_cell, max_cell} ->
        surfaces
        |> Enum.filter(fn {cell, _tile} -> within?(cell, min_cell, max_cell) end)
        |> Enum.map(&elem(&1, 1))
    end
  end

  defp scan_box(%{position: %{x: x, y: y, z: z}} = character) do
    b = @block_size

    case facing(character) do
      90 -> box({x + 3 * b, y + 2 * b, z - div(b, 2)}, {x + b, y - 2 * b, z - 3 * b})
      -180 -> box({x - 2 * b, y + 3 * b, z - div(b, 2)}, {x + 2 * b, y + b, z - 3 * b})
      -90 -> box({x - 3 * b, y - 2 * b, z - div(b, 2)}, {x - b, y + 2 * b, z - 3 * b})
      0 -> box({x + 2 * b, y - 3 * b, z - div(b, 2)}, {x - 2 * b, y - b, z - 3 * b})
      _ -> nil
    end
  end

  defp scan_box(_character), do: nil

  defp box({x1, y1, z1}, {x2, y2, z2}) do
    {cell(%{x: min(x1, x2), y: min(y1, y2), z: min(z1, z2)}),
     cell(%{x: max(x1, x2), y: max(y1, y2), z: max(z1, z2)})}
  end

  defp within?({x, y, z}, {min_x, min_y, min_z}, {max_x, max_y, max_z}) do
    x >= min_x and x <= max_x and y >= min_y and y <= max_y and z >= min_z and z <= max_z
  end

  # rotations snap to the four diagonal facings the map grid uses
  defp facing(%{rotation: %{z: z}}) do
    case rem(round(z / 90) * 90, 360) do
      180 -> -180
      -180 -> -180
      270 -> -90
      -270 -> 90
      value -> value
    end
  end

  defp facing(_character), do: nil

  defp cell(%{x: x, y: y, z: z}), do: {block(x), block(y), block(z)}
  defp cell({_x, _y, _z} = cell), do: cell

  defp block(value), do: round(value / @block_size)

  # the bobber sits one block above the water surface
  defp spawn_guide(character, tiles) do
    tile = Enum.min_by(tiles, &distance_2d(&1.position, character.position))

    case Context.Field.next_object_id(character) do
      {:ok, object_id} ->
        {:ok,
         %{
           object_id: object_id,
           character_id: character.id,
           type: :fishing,
           position: %Coord{
             x: tile.position.x * @block_size,
             y: tile.position.y * @block_size,
             z: (tile.position.z + 1) * @block_size
           },
           rotation: %Coord{x: 0, y: 0, z: 0}
         }}

      _ ->
        {:error, :s_fishing_error_system_error}
    end
  end

  defp distance_2d(%{x: x, y: y}, %{x: px, y: py}) do
    dx = x * @block_size - px
    dy = y * @block_size - py
    dx * dx + dy * dy
  end

  defp distance_2d(_tile, _position), do: 0

  # ---- fish selection ----

  # a water spot that also lists seawater always rolls its seawater fish
  defp available_fishes(spot, :water) do
    if :seawater in spot.liquid_types do
      available_fishes(spot, :seawater)
    else
      collect_fishes(spot, :water)
    end
  end

  defp available_fishes(spot, liquid_type), do: collect_fishes(spot, liquid_type)

  defp collect_fishes(spot, liquid_type) do
    box_fishes(Storage.Tables.Fish.global_box(spot.global_fish_box_id), spot, liquid_type) ++
      box_fishes(
        Storage.Tables.Fish.individual_box(spot.individual_fish_box_id),
        spot,
        liquid_type
      )
  end

  defp box_fishes({:ok, box}, spot, liquid_type) do
    if box.probability < :rand.uniform(10_000) - 1 do
      []
    else
      Enum.flat_map(box.fishes, &weighted_fish(&1, spot, liquid_type))
    end
  end

  defp box_fishes(:error, _spot, _liquid_type), do: []

  defp weighted_fish({fish_id, weight}, spot, liquid_type) do
    case Storage.Tables.Fish.fish(fish_id) do
      {:ok, fish} -> if catchable?(fish, spot, liquid_type), do: [{fish, weight}], else: []
      :error -> []
    end
  end

  defp catchable?(fish, spot, liquid_type) do
    fish.fluid_habitat == liquid_type and
      (fish.ignore_spot_mastery or
         (spot.min_mastery <= fish.mastery and spot.max_mastery >= fish.mastery))
  end

  defp pick_weighted(fishes) do
    total = Enum.reduce(fishes, 0, fn {_fish, weight}, sum -> sum + weight end)
    roll = :rand.uniform(max(total, 1))

    Enum.reduce_while(fishes, roll, fn {fish, weight}, remaining ->
      if remaining <= weight, do: {:halt, fish}, else: {:cont, remaining - weight}
    end)
    |> case do
      %{} = fish -> fish
      _ -> fishes |> List.first() |> elem(0)
    end
  end

  # a bite lands inside the bore window; a miss runs past it so the client
  # times out
  defp bite_timer(rod, fish, auto_fishing?) do
    bore = constant(:fisher_bore_duration, @default_bore_duration)

    if :rand.uniform(10_000) - 1 < fish.bait_probability do
      ticks = bore - rod.reduce_time

      fight? =
        not auto_fishing? and
          :rand.uniform(10_000) - 1 < constant(:fish_fighting_prop, @default_fight_probability)

      {random_between(ticks - div(ticks, 3), ticks), fight?}
    else
      {random_between(bore + 1, bore * 2), false}
    end
  end

  # Smart Push sells the auto-fishing effect; the client reels in on its own
  # and never runs the fight minigame while it is up
  defp auto_fishing?(character) do
    Context.Field.call(character, {:has_buff_event?, character.object_id, :auto_fish}) == true
  end

  defp random_between(min, max) when max > min, do: min + :rand.uniform(max - min) - 1
  defp random_between(min, _max), do: max(min, 1)

  # ---- catching ----

  defp roll_size(fish) do
    small = fish.small_size
    big = fish.big_size

    case :rand.uniform() do
      roll when roll < 0.025 -> random_between(big.max, big.max * 2)
      roll when roll < 0.03 -> random_between(small.min, small.max)
      roll when roll < 0.15 -> random_between(small.max, big.min)
      _ -> random_between(small.min, small.max)
    end
  end

  defp land_fish(character, fish, size, auto?) do
    prize? = size >= fish.big_size.max

    {:ok, character, entry, first?} =
      Managers.Character.call(character.id, {:record_catch, fish.id, size, prize?})

    push(character, Packets.Fishing.catch_fish(fish.id, size, auto?, entry))

    if first? do
      update_conditions(character, :fish_collect, fish.id)
    end

    if size >= fish.big_size.min do
      update_conditions(character, :fish_goldmedal, fish.id)
    end

    if prize? do
      update_conditions(character, :fish_big, fish.id)
      Context.Field.broadcast(character, Packets.Fishing.prize_fish(character.name, fish.id))
    end

    update_conditions(character, :fish, fish.id)

    # the reference declares the fishing exp type but never awards it; the
    # other life skills all grant their activity exp
    Managers.Character.cast(
      character,
      {:earn_exp, Storage.Tables.ExpTable.typed_exp(:fishing, character.level)}
    )

    award_mastery(character, fish, entry, first?, prize?)
  end

  # mastery is only awarded every `point_count` catches, doubled for a first
  # catch or a prize fish
  defp award_mastery(character, fish, entry, first?, prize?) do
    exp =
      cond do
        prize? -> fish.mastery_exp * 2
        first? -> fish.mastery_exp * 2
        rem(entry.total_caught, max(fish.point_count, 1)) == 0 -> fish.mastery_exp
        true -> 0
      end

    if exp == 0 do
      character
    else
      character = Context.Mastery.add(character, :fishing, exp)
      grade = Context.Mastery.grade(character, :fishing)

      push(
        character,
        Packets.Fishing.increase_mastery(fish.id, grade, exp, caught_type(first?, prize?))
      )

      character
    end
  end

  defp caught_type(_first?, true), do: :prize
  defp caught_type(true, _prize?), do: :first_kind
  defp caught_type(_first?, _prize?), do: :default

  defp catch_items(character, spot) do
    items =
      global_items(character, spot) ++ individual_items(character, spot)

    granted = Enum.filter(items, &(grant_item(character, &1) == :ok))

    if granted != [] do
      push(character, Packets.Fishing.catch_item(granted))
    end

    character
  end

  defp global_items(_character, %{global_drop_box_id: id}) when id <= 0, do: []

  defp global_items(character, %{global_drop_box_id: id, spot_level: level}) do
    Context.Drops.global_items(id, max(level, 1), character.map_id)
  end

  defp individual_items(_character, %{individual_drop_box_id: id}) when id <= 0, do: []

  defp individual_items(character, %{individual_drop_box_id: id}) do
    Context.Drops.individual_items(id, character, character.map_id)
  end

  defp grant_item(character, item) do
    case Managers.Inventory.add_item(character, item) do
      {:ok, result} ->
        {_status, inventory_item} = result
        push(character, Packets.InventoryItem.add_item(result, character))
        push(character, Packets.InventoryItem.mark_item_new(inventory_item))
        Managers.Quest.notify_item_acquired(character, inventory_item)
        :ok

      _ ->
        :error
    end
  end

  defp constant(key, default) do
    case Storage.Tables.Constants.get(key) do
      value when is_integer(value) and value > 0 -> value
      _ -> default
    end
  end

  defp update_conditions(character, type, fish_id) do
    Managers.Quest.update_conditions(
      character.id,
      type,
      1,
      "",
      character.map_id,
      "",
      fish_id
    )
  end
end
