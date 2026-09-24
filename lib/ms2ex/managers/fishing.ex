defmodule Ms2ex.Managers.Fishing do
  use GenServer
  use Ms2ex.Managers.Managed, prefix: "fishing", key: :character_id

  alias Ms2ex.Context
  alias Ms2ex.Managers
  alias Ms2ex.Packets
  alias Ms2ex.Schema
  alias Ms2ex.Storage
  alias Ms2ex.Types.Coord

  import Ms2ex.Net.SenderSession, only: [push: 2]

  @moduledoc """
  The fishing manager owns a character's fishing session — the active rod,
  the water tiles it reaches, the fish currently biting — and the fish
  album.

  The album persists on the characters row when a catch is recorded. The
  flows run inside this process and send every fishing packet; the behaviour
  logic they draw on (tile reachability, fish selection, timers, rolls,
  session transitions) lives in `Ms2ex.Context.Fishing`.
  """

  def start(%Schema.Character{} = character) do
    case GenServer.start(__MODULE__, character, name: process_name(character.id)) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      error -> error
    end
  end

  def stop(%Schema.Character{id: id}), do: stop(id)

  def stop(id) when is_integer(id) do
    case Process.whereis(process_name(id)) do
      nil -> :ok
      pid -> GenServer.stop(pid)
    end
  end

  # ---- client API ----

  @doc "Fish album, keyed by fish id."
  @spec album(integer()) :: map() | :error
  def album(character_id), do: call(character_id, :album)

  @doc "The active fishing session, or nil when the player is not fishing."
  @spec session(integer()) :: map() | nil | :error
  def session(character_id), do: call(character_id, :session)

  @doc "Casts the rod: validates it, finds reachable water and spawns the bobber."
  @spec prepare(Schema.Character.t(), integer()) :: :ok | {:error, atom()}
  def prepare(character, rod_uid), do: call(character.id, {:prepare, rod_uid})

  @doc "Consumes a bait item and applies its timed lure effect."
  @spec select_bait(Schema.Character.t(), integer()) :: :ok | {:error, atom()}
  def select_bait(character, bait_uid), do: call(character.id, {:select_bait, bait_uid})

  @doc """
  Applies a lure by item id — the client picks the lure from the item book,
  not from the inventory.
  """
  @spec select_bait_item(Schema.Character.t(), integer()) :: :ok | {:error, atom()}
  def select_bait_item(character, item_id), do: call(character.id, {:select_bait_item, item_id})

  @doc "Applies a lure by inventory item."
  @spec use_bait_item(Schema.Character.t(), Schema.Item.t()) :: :ok | {:error, atom()}
  def use_bait_item(character, item), do: call(character.id, {:use_bait_item, item})

  @doc "Drops the line on a tile and arms the bite timer."
  @spec start(Schema.Character.t(), map()) :: :ok | {:error, atom()}
  def start(character, position), do: call(character.id, {:start, position})

  @doc "Resolves the bite: a success lands the fish and the spot's loot."
  @spec catch_fish(Schema.Character.t(), boolean()) :: :ok | {:error, atom()}
  def catch_fish(character, success?), do: call(character.id, {:catch_fish, success?})

  @doc "Reels in: removes the bobber and clears the session."
  @spec reel_in(Schema.Character.t()) :: :ok
  def reel_in(character), do: call(character.id, :reel_in)

  @doc "The client lost the fight minigame; the bite stays but the game ends."
  @spec fail_minigame(Schema.Character.t()) :: :ok
  def fail_minigame(character), do: call(character.id, :fail_minigame)

  @doc "Tracks where the player dragged the bobber; nothing waits on it."
  @spec move_guide(Schema.Character.t() | integer(), map(), Coord.t()) :: :ok
  def move_guide(character, position, rotation) do
    cast(character, {:move_guide, position, rotation})
  end

  # ---- server callbacks ----

  @impl true
  def init(character) do
    {:ok,
     %{
       character_id: character.id,
       # the loaded characters row: pushes, field calls and album persistence
       row: character,
       album: Map.get(character, :fish_album) || %{},
       session: nil
     }}
  end

  @impl true
  def handle_call(:album, _from, state), do: {:reply, state.album, state}

  @impl true
  def handle_call(:session, _from, state), do: {:reply, state.session, state}

  @impl true
  def handle_call({:prepare, rod_uid}, _from, state) do
    character = state.row

    with nil <- state.session,
         {:ok, rod} <- rod_metadata(character, rod_uid),
         :ok <- check_rod_mastery(character, rod),
         {:ok, spot} <- Storage.Tables.Fish.spot(character.map_id),
         :ok <- check_spot_mastery(character, spot),
         [_ | _] = tiles <- Context.Fishing.reachable_tiles(character),
         %Coord{} = position <- Context.Fishing.guide_position(tiles, character.position),
         {:ok, object_id} <- Managers.Field.next_object_id(character) do
      guide = %{
        object_id: object_id,
        character_id: character.id,
        type: :fishing,
        position: position,
        rotation: %Coord{x: 0, y: 0, z: 0}
      }

      fishing = %{
        rod_uid: rod_uid,
        rod: rod,
        spot: spot,
        tiles: Context.Fishing.session_tiles(tiles),
        guide: guide,
        bait: nil,
        bait_used?: false,
        tile: nil,
        fish_id: nil,
        fight_game?: false
      }

      push(character, Packets.Fishing.load_tiles(tiles, rod.reduce_time))
      Managers.Field.broadcast(character, Packets.GuideObject.create(guide))
      push(character, Packets.Fishing.prepare(rod_uid))

      {:reply, :ok, %{state | session: fishing}}
    else
      %{} -> {:reply, {:error, :s_fishing_error_system_error}, state}
      [] -> {:reply, {:error, :s_fishing_error_notexist_fish}, state}
      :error -> {:reply, {:error, :s_fishing_error_notexist_fish}, state}
      {:error, error} -> {:reply, {:error, error}, state}
      _ -> {:reply, {:error, :s_fishing_error_system_error}, state}
    end
  end

  @impl true
  def handle_call({:select_bait, 0}, _from, state) do
    {:reply, :ok, %{state | session: Context.Fishing.select_bait(state.session, nil)}}
  end

  @impl true
  def handle_call({:select_bait, bait_uid}, _from, state) do
    character = state.row

    with %Schema.Item{} = item <- Managers.Inventory.get(character, bait_uid),
         {:ok, state} <- use_bait_item(state, character, item) do
      {:reply, :ok, state}
    else
      _ -> {:reply, {:error, :s_fishing_error_invalid_item}, state}
    end
  end

  @impl true
  def handle_call({:select_bait_item, 0}, _from, state) do
    handle_call({:select_bait, 0}, :from, state)
  end

  @impl true
  def handle_call({:select_bait_item, item_id}, _from, state) do
    character = state.row

    with %Schema.Item{} = item <- find_lure_item(character, item_id),
         {:ok, state} <- use_bait_item(state, character, item) do
      {:reply, :ok, state}
    else
      _ -> {:reply, {:error, :s_fishing_error_invalid_item}, state}
    end
  end

  @impl true
  def handle_call({:use_bait_item, item}, _from, state) do
    character = state.row

    case use_bait_item(state, character, item) do
      {:ok, state} -> {:reply, :ok, state}
      {:error, error} -> {:reply, {:error, error}, state}
    end
  end

  @impl true
  def handle_call({:start, position}, _from, state) do
    character = state.row

    with %{} = fishing <- state.session,
         %{} = tile <- Context.Fishing.tile_at(fishing.tiles, position),
         {bait_used?, cast_bait, next_bait} <- consume_bait(character, fishing.bait),
         [_ | _] = fishes <-
           Context.Fishing.available_fishes(fishing.spot, tile.liquid_type, cast_bait) do
      fish = Context.Fishing.pick_weighted(fishes)

      {ticks, fight_game?} =
        Context.Fishing.bite_timer(fishing.rod, fish, auto_fishing?(character), cast_bait)

      session = Context.Fishing.bite(fishing, tile, fish.id, fight_game?, bait_used?, next_bait)

      push(character, Packets.Fishing.start(Ms2ex.sync_ticks() + ticks, fight_game?))
      {:reply, :ok, %{state | session: session}}
    else
      nil -> {:reply, {:error, :s_fishing_error_system_error}, state}
      [] -> {:reply, {:error, :s_fishing_error_notexist_fish}, state}
      _ -> {:reply, {:error, :s_fishing_error_system_error}, state}
    end
  end

  @impl true
  def handle_call({:catch_fish, success?}, _from, state) do
    character = state.row

    with %{fish_id: fish_id} = fishing when not is_nil(fish_id) <- state.session,
         {:ok, fish} <- Storage.Tables.Fish.fish(fish_id) do
      size = Context.Fishing.roll_size(fish)
      auto? = auto_fishing?(character)

      if success? do
        state =
          character
          |> land_fish(state, fish, size, auto?)
          |> catch_items(character, fishing.spot)

        {:reply, :ok, state}
      else
        update_conditions(character, :fish_fail, fish.id)
        push(character, Packets.Fishing.catch_fish(fish.id, size, auto?))
        session = Context.Fishing.clear_minigame(state.session)
        {:reply, :ok, %{state | session: session}}
      end
    else
      _ -> {:reply, {:error, :s_fishing_error_system_error}, state}
    end
  end

  @impl true
  def handle_call(:reel_in, _from, state) do
    case state.session do
      nil ->
        {:reply, :ok, state}

      %{guide: guide} ->
        character = state.row
        push(character, Packets.Fishing.stop())
        Managers.Field.broadcast(character, Packets.GuideObject.remove(guide))
        {:reply, :ok, %{state | session: nil}}
    end
  end

  @impl true
  def handle_call(:fail_minigame, _from, state) do
    session = Context.Fishing.clear_minigame(state.session)
    {:reply, :ok, %{state | session: session}}
  end

  @impl true
  def handle_cast({:move_guide, position, rotation}, state) do
    {:noreply, %{state | session: Context.Fishing.move_guide(state.session, position, rotation)}}
  end

  # ---- flow internals ----

  # applies the lure's buff, consumes the item and arms the bait
  defp use_bait_item(state, character, item) do
    with %{metadata: metadata} = item <- Context.Items.load_metadata(item),
         true <- Context.Fishing.fishing_lure?(metadata),
         effect_id when is_integer(effect_id) <- metadata[:skill_id],
         effect_level when is_integer(effect_level) <- metadata[:skill_level],
         %{} <- Storage.Skills.get_effect(effect_id, effect_level),
         {:ok, lure} <- Storage.Tables.Fish.lure(effect_id),
         :ok <- Managers.Field.add_effect_buff(character, effect_id, effect_level),
         {:ok, consumed} <- consume_lure_item(item) do
      push(character, Packets.InventoryItem.consume(consumed))

      bait = %{effect_id: effect_id, effect_level: effect_level, lure: lure}
      session = Context.Fishing.select_bait(state.session, bait)
      {:ok, %{state | session: session}}
    else
      _ -> {:error, :s_fishing_error_invalid_item}
    end
  end

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
    if Managers.Mastery.value(character.id, :fishing) >= rod.min_mastery do
      :ok
    else
      {:error, :s_fishing_error_fishingrod_mastery}
    end
  end

  defp check_spot_mastery(character, spot) do
    if Managers.Mastery.value(character.id, :fishing) >= spot.min_mastery do
      :ok
    else
      {:error, :s_fishing_error_lack_mastery}
    end
  end

  # Smart Push sells the auto-fishing effect; the client reels in on its own
  # and never runs the fight minigame while it is up
  defp auto_fishing?(character) do
    Managers.Field.has_buff_event?(character, :auto_fish)
  end

  defp find_lure_item(character, item_id) do
    character
    |> Managers.Inventory.list_items()
    |> Enum.find(fn item -> item.item_id == item_id end)
  end

  defp consume_lure_item(item) do
    case Managers.Inventory.consume(item) do
      {action, _item} = consumed when action in [:update, :delete] -> {:ok, consumed}
      _ -> :error
    end
  end

  # the selected lure only counts while its buff is up
  defp consume_bait(character, bait) do
    bait = active_bait(character, bait)
    {not is_nil(bait), bait, bait}
  end

  defp active_bait(character, bait) do
    if active_lure?(character, bait), do: bait, else: active_lure(character)
  end

  defp active_lure?(_character, nil), do: false

  defp active_lure?(character, %{effect_id: effect_id}),
    do: Managers.Field.has_buff?(character, effect_id)

  defp active_lure(character) do
    Storage.Tables.Fish.lures()
    |> Enum.find(fn %{id: effect_id} -> Managers.Field.has_buff?(character, effect_id) end)
    |> case do
      nil -> nil
      lure -> %{effect_id: lure.id, effect_level: lure.buff_level, lure: lure}
    end
  end

  defp land_fish(character, state, fish, size, auto?) do
    prize? = size >= fish.big_size.max

    # the album persists with the catch so a crash cannot duplicate the
    # "first catch" rewards
    {album, entry, first?} = Context.Fishing.record_catch(state.album, fish.id, size, prize?)
    {:ok, row} = Context.Characters.persist(state.row, %{fish_album: album})
    state = %{state | album: album, row: row}

    push(character, Packets.Fishing.catch_fish(fish.id, size, auto?, entry))

    if first?, do: update_conditions(character, :fish_collect, fish.id)

    if size >= fish.big_size.min do
      update_conditions(character, :fish_goldmedal, fish.id)
    end

    if prize? do
      update_conditions(character, :fish_big, fish.id)
      Managers.Field.broadcast(character, Packets.Fishing.prize_fish(character.name, fish.id))
    end

    update_conditions(character, :fish, fish.id)

    if Map.get(state.session || %{}, :bait_used?) do
      update_conditions(character, :fish_success_bait, fish.id)
    end

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
      Managers.Mastery.add(character.id, :fishing, exp)
      grade = Managers.Mastery.grade(character.id, :fishing)

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

  defp catch_items(state, character, spot) do
    items = global_items(character, spot) ++ individual_items(character, spot)
    granted = Enum.filter(items, &(grant_item(character, &1) == :ok))

    if granted != [] do
      push(character, Packets.Fishing.catch_item(granted))
    end

    state
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
    case Managers.Inventory.add_item_or_mail(character, item) do
      {:ok, result} ->
        {_status, inventory_item} = result
        push(character, Packets.InventoryItem.add_item(result, character))
        push(character, Packets.InventoryItem.mark_item_new(inventory_item))
        Managers.Quest.notify_item_acquired(character, inventory_item)
        :ok

      {:mailed, _mail} ->
        :ok

      _ ->
        :ok
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
