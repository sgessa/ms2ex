defmodule Ms2ex.Managers.Field.Liftable do
  @moduledoc """
  Quest liftable props (e.g. the carried squire): rendered by the client
  from the field-enter batch, picked up with the interact key (recv
  LIFTABLE), and installed at a liftable target box — which fires the
  quest's item_move condition.
  """

  alias Ms2ex.Context
  alias Ms2ex.Managers
  alias Ms2ex.Packets
  alias Ms2ex.Schema
  alias Ms2ex.Storage

  @grid_size 150

  def init_liftables(state) do
    meta = Storage.Maps.get_meta(state.map_id)

    liftables =
      meta
      |> Map.get(:liftables, [])
      |> Map.new(fn liftable ->
        liftable = Map.put_new(liftable, :count, Map.get(liftable, :stack_count, 1))
        liftable = Map.put(liftable, :state, :default)
        {liftable.uuid, liftable}
      end)

    targets =
      meta
      |> Map.get(:liftable_target_boxes, [])
      |> Map.new(fn target -> {grid_key(target[:position]), target} end)

    state
    |> Map.put(:liftables, liftables)
    |> Map.put(:liftable_target_boxes, targets)
    |> Map.put(:held_liftables, %{})
  end

  def liftables_for_enter(state) do
    state |> Map.get(:liftables, %{}) |> Map.values()
  end

  # the client picks a liftable up with the interact key
  def pickup(state, character_id, uuid) do
    case Map.get(Map.get(state, :liftables, %{}), uuid) do
      %{count: count} = liftable when count > 0 ->
        liftable = %{liftable | count: count - 1, state: :removed}

        Context.Field.broadcast(state.topic, Packets.Liftable.update(liftable))
        state = put_in(state, [:liftables, uuid], liftable)

        {:ok, character} = Managers.Character.call(character_id, :lookup)

        held = %{item_id: liftable.item_id, object_id: character.object_id, source: liftable}
        state = put_in(state, [:held_liftables, character_id], held)

        Context.Field.broadcast(
          state.topic,
          Packets.SetCraftMode.liftable(character.object_id, liftable.item_id)
        )

        state

      _ ->
        state
    end
  end

  # the client places the held liftable at a grid tile: the prop becomes a
  # fresh field liftable rendered at that tile, a matching liftable target
  # box fires the quest's item_move condition, and the carry pose clears
  def place(state, character_id, grid, item_id, rotation) do
    held = Map.get(state.held_liftables, character_id)

    if held && held.item_id == item_id do
      state = Map.put(state, :held_liftables, Map.delete(state.held_liftables, character_id))
      {:ok, character} = Managers.Character.call(character_id, :lookup)

      {uuid, placed} = placed_liftable(grid, held)
      state = put_in(state, [:liftables, uuid], placed)

      Context.Field.broadcast(state.topic, Packets.Liftable.add(placed))

      Context.Field.broadcast(
        state.topic,
        Packets.ResponseCube.place_liftable(character.object_id, item_id, grid, rotation)
      )

      Context.Field.broadcast(state.topic, Packets.SetCraftMode.stop(character.object_id))
      Context.Field.broadcast(state.topic, Packets.Liftable.update(placed))

      case Map.get(state.liftable_target_boxes, grid) do
        %{target: target} ->
          Managers.Quest.update_conditions(character_id, :item_move, 1, "", target, "", item_id)

        _ ->
          :ok
      end

      state
    else
      state
    end
  end

  # the placed prop keeps the source liftable's quest masks and can be
  # picked up again; TODO expire it after item_lifetime + finish_time
  defp placed_liftable(grid, held) do
    uuid = "4_" <> Integer.to_string(grid_to_int(grid))
    source = held.source

    placed = %{
      uuid: uuid,
      item_id: source.item_id,
      count: 1,
      state: :default,
      mask_quest_id: Map.get(source, :mask_quest_id, ""),
      mask_quest_state: Map.get(source, :mask_quest_state, ""),
      effect_quest_id: Map.get(source, :effect_quest_id, ""),
      effect_quest_state: Map.get(source, :effect_quest_state, ""),
      react_effect: Map.get(source, :react_effect, false)
    }

    {uuid, placed}
  end

  defp grid_to_int({x, y, z}) do
    import Bitwise
    (x &&& 0xFF) ||| (y &&& 0xFF) <<< 8 ||| (z &&& 0xFF) <<< 16
  end

  # runs during character teardown (relog/logout): the character struct is
  # already in hand, so no manager round-trip that could hit a torn-down
  # character process
  def drop(state, %Schema.Character{} = character) do
    state = Map.put(state, :held_liftables, Map.delete(state.held_liftables, character.id))
    Context.Field.broadcast(state.topic, Packets.SetCraftMode.stop(character.object_id))
    state
  end

  defp grid_key(nil), do: nil

  defp grid_key(position) do
    {
      grid_coord(position[:x]),
      grid_coord(position[:y]),
      grid_coord(position[:z])
    }
  end

  defp grid_coord(value) when is_number(value), do: round(value / @grid_size)
  defp grid_coord(_), do: 0
end
