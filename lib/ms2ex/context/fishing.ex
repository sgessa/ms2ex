defmodule Ms2ex.Context.Fishing do
  @moduledoc """
  Pure fishing behaviour: water-tile reachability, fish selection, bite
  timers and catch rolls, plus the session-map transitions.

  Stateless by design — the session and album state live in
  `Ms2ex.Managers.Fishing`, which turns these results into packets and
  persistence.
  """

  alias Ms2ex.Storage
  alias Ms2ex.Types.Coord

  @block_size 150
  @default_bore_duration 15_000
  @default_fight_probability 5000

  # ---- session transitions ----

  @doc "Drops the line: stores the tile, fish and bait state for the cast."
  def bite(nil, _tile, _fish_id, _fight_game?, _bait_used?, _bait), do: nil

  def bite(fishing, tile, fish_id, fight_game?, bait_used?, bait) do
    Map.merge(fishing, %{
      tile: tile,
      fish_id: fish_id,
      bait_used?: bait_used?,
      bait: bait,
      fight_game?: fight_game?
    })
  end

  @doc "Keeps the selected bait for the active session."
  def select_bait(nil, _bait), do: nil
  def select_bait(fishing, bait), do: Map.put(fishing, :bait, bait)

  @doc "The client lost the fight minigame; the bite stays but the game ends."
  def clear_minigame(nil), do: nil
  def clear_minigame(fishing), do: %{fishing | fight_game?: false}

  @doc "Tracks where the player dragged the bobber."
  def move_guide(nil, _position, _rotation), do: nil

  def move_guide(%{guide: guide} = fishing, position, rotation) do
    guide = %{guide | position: position, rotation: rotation}
    %{fishing | guide: guide}
  end

  @doc """
  Records a catch in the album. Returns the updated album, the entry and
  whether this was the first catch of that kind.
  """
  @spec record_catch(map(), integer(), integer(), boolean()) :: {map(), map(), boolean()}
  def record_catch(album, fish_id, size, prize?) do
    existing = Map.get(album, fish_id)

    entry =
      case existing do
        nil ->
          %{
            fish_id: fish_id,
            total_caught: 1,
            total_prize: bool_to_int(prize?),
            largest_size: size
          }

        entry ->
          %{
            entry
            | total_caught: entry.total_caught + 1,
              total_prize: entry.total_prize + bool_to_int(prize?),
              largest_size: max(entry.largest_size, size)
          }
      end

    {Map.put(album, fish_id, entry), entry, is_nil(existing)}
  end

  # ---- water tiles ----

  @doc """
  The water tiles the player can fish into: the client only lets a player
  fish into the quadrant they face, so the box in front of them is scanned
  for surface water.
  """
  def reachable_tiles(character) do
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

  @doc "Indexes the reachable tiles by their block cell."
  def session_tiles(tiles) do
    Map.new(tiles, &{cell(&1.position), &1})
  end

  @doc "The indexed tile at the given position's block cell, if any."
  def tile_at(tiles, position), do: Map.get(tiles, cell(position))

  @doc """
  The bobber position: one block above the water surface, on the reachable
  tile closest to the player.
  """
  def guide_position(tiles, character_position) do
    tile = Enum.min_by(tiles, &distance_2d(&1.position, character_position))

    %Coord{
      x: tile.position.x * @block_size,
      y: tile.position.y * @block_size,
      z: (tile.position.z + 1) * @block_size
    }
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

  defp distance_2d(%{x: x, y: y}, %{x: px, y: py}) do
    dx = x * @block_size - px
    dy = y * @block_size - py
    dx * dx + dy * dy
  end

  defp distance_2d(_tile, _position), do: 0

  # ---- fish selection ----

  @doc "The fish that can bite on the given tile, given the active lure."
  def available_fishes(spot, liquid_type, bait) do
    case bait do
      nil ->
        available_fishes(spot, liquid_type)

      %{lure: lure} ->
        base =
          if liquid_type == :water and :seawater in spot.liquid_types do
            available_fishes(spot, :seawater)
          else
            available_fishes(spot, liquid_type)
          end

        base ++ lure_fishes(lure, spot, liquid_type)
    end
  end

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

  defp lure_fishes(%{spawns: spawns}, spot, liquid_type) do
    Enum.flat_map(spawns, &lure_fish(&1, spot, liquid_type))
  end

  defp lure_fishes(_lure, _spot, _liquid_type), do: []

  defp lure_fish(%{fish_id: fish_id, rate: rate}, spot, liquid_type) do
    with {:ok, fish} <- Storage.Tables.Fish.fish(fish_id),
         true <- catchable?(fish, spot, liquid_type) do
      [{fish, rate}]
    else
      _ -> []
    end
  end

  # a fish marked for all habitats bites in any liquid
  defp catchable?(fish, spot, liquid_type) do
    fish.fluid_habitat in [liquid_type, :all] and
      (fish.ignore_spot_mastery or
         (spot.min_mastery <= fish.mastery and spot.max_mastery >= fish.mastery))
  end

  @doc "Picks the fish that bites, weighted by the box weights."
  def pick_weighted(fishes) do
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

  # ---- timers and rolls ----

  @doc """
  The bite delay and whether the catch turns into a fight minigame: a bite
  lands inside the bore window, a miss runs past it so the client times out.
  """
  def bite_timer(rod, fish, auto_fishing?, bait) do
    bore = constant(:fisher_bore_duration, @default_bore_duration)

    if :rand.uniform(10_000) - 1 < bait_probability(fish, bait) do
      ticks = bore - rod.reduce_time

      fight? =
        not auto_fishing? and
          :rand.uniform(10_000) - 1 < constant(:fish_fighting_prop, @default_fight_probability)

      {random_between(ticks - div(ticks, 3), ticks), fight?}
    else
      {random_between(bore + 1, bore * 2), false}
    end
  end

  defp bait_probability(fish, nil), do: fish.bait_probability

  defp bait_probability(fish, %{effect_id: effect_id, lure: lure}) do
    bait_effect_ids = Map.get(fish, :bait_effect_ids, [])

    if effect_id in bait_effect_ids do
      lure
      |> Map.get(:catches, [])
      |> Enum.find_value(fish.bait_probability, fn
        %{rank: rank, probability: probability} when rank == fish.rarity -> probability
        _ -> nil
      end)
      |> max(fish.bait_probability)
    else
      fish.bait_probability
    end
  end

  @doc "The caught fish's size."
  def roll_size(fish) do
    small = fish.small_size
    big = fish.big_size

    case :rand.uniform() do
      roll when roll < 0.025 -> random_between(big.max, big.max * 2)
      roll when roll < 0.03 -> random_between(small.min, small.max)
      roll when roll < 0.15 -> random_between(small.max, big.min)
      _ -> random_between(small.min, small.max)
    end
  end

  @doc "True when the item's metadata marks a fishing lure."
  def fishing_lure?(%{property: %{tag: :fishing_lure}}), do: true
  def fishing_lure?(_metadata), do: false

  defp random_between(min, max) when max > min, do: min + :rand.uniform(max - min) - 1
  defp random_between(min, _max), do: max(min, 1)

  defp bool_to_int(true), do: 1
  defp bool_to_int(_prize?), do: 0

  defp constant(key, default) do
    case Storage.Tables.Constants.get(key) do
      value when is_integer(value) and value > 0 -> value
      _ -> default
    end
  end
end
