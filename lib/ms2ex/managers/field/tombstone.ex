defmodule Ms2ex.Managers.Field.Tombstone do
  alias Ms2ex.Context
  alias Ms2ex.Managers
  alias Ms2ex.Packets

  def add(character, state) do
    tombstone = Ms2ex.Types.Tombstone.new(character, Map.get(character, :death_count, 0) || 0)
    Context.Field.broadcast(state.topic, Packets.Tombstone.bytes(tombstone))
    put_in(state, [:tombstones, character.id], tombstone)
  end

  def remove(character_id, state) do
    update_in(state, [:tombstones], &Map.delete(&1, character_id))
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
