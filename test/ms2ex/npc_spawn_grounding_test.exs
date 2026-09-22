defmodule Ms2ex.NpcSpawnGroundingTest do
  # scattered spawn positions snap to the walkable surface; the snap is
  # stubbed at the Navigation boundary so the tests pin the spawn plumbing,
  # not the mesh
  use Ms2ex.DataCase, async: false

  alias Ms2ex.Managers.Field.Npc
  alias Ms2ex.Types

  setup {Mimic, :set_mimic_global}

  setup do
    %{
      state: %{local_id_counter: 0, map_id: 52_000_001, npcs: %{}, topic: "field:test"},
      position: %Types.Coord{x: 2700.0, y: -750.0, z: 1200.0}
    }
  end

  test "a spawn without a radius stands at its authored position", %{
    state: state,
    position: position
  } do
    {field_npc, _state} = Npc.spawn_npc(state, friendly_npc(), npc_spawn(position))

    assert field_npc.position == position
    assert field_npc.origin == field_npc.position
  end

  test "a scattered spawn lands on the walkable surface at its scattered spot", %{
    state: state,
    position: position
  } do
    Mimic.stub(Ms2ex.Navigation, :snap_to_floor, fn _map_id, pos -> %{pos | z: 1000.0} end)

    {field_npc, _state} =
      Npc.spawn_npc(state, mob_npc(), npc_spawn(position, spawn_radius: 50.0))

    assert field_npc.position.z == 1000.0

    distance =
      :math.sqrt(
        :math.pow(field_npc.position.x - position.x, 2) +
          :math.pow(field_npc.position.y - position.y, 2)
      )

    assert distance <= 50.0
  end

  test "a scattered spawn without walkable ground falls back to the authored spawn", %{
    state: state,
    position: position
  } do
    Mimic.stub(Ms2ex.Navigation, :snap_to_floor, fn _map_id, _pos -> nil end)

    {field_npc, _state} =
      Npc.spawn_npc(state, mob_npc(), npc_spawn(position, spawn_radius: 50.0))

    assert field_npc.position == position
  end

  test "plain-map spawn positions flow through the same scatter path", %{
    state: state,
    position: position
  } do
    Mimic.stub(Ms2ex.Navigation, :snap_to_floor, fn _map_id, pos -> %{pos | z: 1000.0} end)

    {field_npc, _state} =
      Npc.spawn_npc(state, mob_npc(), npc_spawn(Map.from_struct(position), spawn_radius: 50.0))

    assert field_npc.position.z == 1000.0
  end

  defp npc_spawn(position, attrs \\ []) do
    Map.merge(%{spawn_point_id: 101, position: position, rotation: nil}, Map.new(attrs))
  end

  @metadata %{basic: %{friendly: 1, level: 1}, stat: %{stats: %{health: 5}}}

  defp friendly_npc, do: %Types.Npc{id: 29_000_128, metadata: @metadata}

  defp mob_npc,
    do: %Types.Npc{id: 29_000_128, metadata: %{@metadata | basic: %{friendly: 0, level: 1}}}
end
