defmodule Ms2ex.FieldTombstoneTest do
  use Ms2ex.DataCase, async: true

  alias Ms2ex.Managers
  alias Ms2ex.Schema

  @owner_id 7
  @owner_object_id 50_000_042

  # hit counts come from the server constants (hit_per_dead_count * death_count)
  @total_hits 5

  setup do
    topic = "field:tombstone-test:#{System.unique_integer([:positive])}"
    Phoenix.PubSub.subscribe(Ms2ex.PubSub, topic)

    %{state: %{tombstones: %{}, topic: topic}}
  end

  defp owner do
    %Schema.Character{
      id: @owner_id,
      object_id: @owner_object_id,
      death_count: 1,
      name: "Fallen"
    }
  end

  # packet layout: opcode short, object id int, hits byte, total byte
  defp hits_remaining(<<_opcode::16, _oid::32, hits::8, _total::8, _rest::binary>>), do: hits

  test "raising a tombstone announces its hit counts", %{state: state} do
    state = Managers.Field.Tombstone.add(owner(), state)

    tombstone = state.tombstones[@owner_id]
    assert tombstone.object_id == @owner_object_id
    assert tombstone.total_hit_count == @total_hits
    assert tombstone.hits_remaining == @total_hits

    # clients render the revive gauge from the announced counts
    assert_received {:push, packet}
    assert hits_remaining(packet) == @total_hits
  end

  test "each hit broadcasts the updated hits remaining", %{state: state} do
    state = Managers.Field.Tombstone.add(owner(), state)
    assert_received {:push, _raise_packet}

    {:ok, state} = Managers.Field.Tombstone.hit(@owner_object_id, 2, state)

    assert state.tombstones[@owner_id].hits_remaining == @total_hits - 2
    assert_received {:push, packet}
    assert hits_remaining(packet) == @total_hits - 2
  end

  test "clearing a tombstone broadcasts zero hits and drops it", %{state: state} do
    state = Managers.Field.Tombstone.add(owner(), state)
    assert_received {:push, _raise_packet}

    {:ok, state} = Managers.Field.Tombstone.hit(@owner_object_id, 2, state)

    state = Managers.Field.Tombstone.clear(@owner_id, state)

    assert state.tombstones == %{}
    assert_received {:push, hit_packet}
    assert hits_remaining(hit_packet) == @total_hits - 2

    assert_received {:push, clear_packet}
    assert hits_remaining(clear_packet) == 0
  end

  test "clearing an unknown tombstone is a no-op", %{state: state} do
    state = Managers.Field.Tombstone.clear(@owner_id, state)

    assert state.tombstones == %{}
    refute_received {:push, _packet}
  end
end
