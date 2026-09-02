defmodule Ms2ex.Managers.Field.Tombstone do
  alias Ms2ex.Context
  alias Ms2ex.Managers
  alias Ms2ex.Packets

  # the tombstone is tracked server-side and announced with its hit counts so
  # clients render the revive gauge; the owner is keyed by character id for
  # the revive lookup. Later updates go out from hit/3 and clear/2
  def add(character, state) do
    tombstone = Ms2ex.Types.Tombstone.new(character, Map.get(character, :death_count, 0) || 0)
    Context.Field.broadcast(state.topic, Packets.Tombstone.bytes(tombstone))
    put_in(state, [:tombstones, character.id], tombstone)
  end

  def remove(character_id, state) do
    update_in(state, [:tombstones], &Map.delete(&1, character_id))
  end

  # a revive broadcasts the tombstone with zero hits remaining so clients tear
  # down the entity and its revive gauge before the revive itself is announced
  def clear(character_id, state) do
    case Map.get(state.tombstones, character_id) do
      nil ->
        state

      tombstone ->
        tombstone = %{tombstone | hits_remaining: 0}
        Context.Field.broadcast(state.topic, Packets.Tombstone.bytes(tombstone))
        remove(character_id, state)
    end
  end

  def hit(object_id, hits, state) do
    case Enum.find(state.tombstones, fn {_id, tombstone} -> tombstone.object_id == object_id end) do
      {owner_id, tombstone} ->
        remaining = max(tombstone.hits_remaining - hits, 0)
        tombstone = %{tombstone | hits_remaining: remaining}
        Context.Field.broadcast(state.topic, Packets.Tombstone.bytes(tombstone))
        state = put_in(state, [:tombstones, owner_id], tombstone)

        if remaining == 0 do
          Managers.Character.cast(owner_id, {:revive, :safe})
        end

        {:ok, state}

      nil ->
        {:error, state}
    end
  end
end
