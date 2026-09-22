defmodule Ms2ex.FieldNpcSpawnPositionTest do
  # spawn scatter is stubbed at the Navigation boundary so the tests pin
  # the scatter contract, not the mesh
  use Ms2ex.DataCase, async: false

  alias Ms2ex.Types.FieldNpc

  setup {Mimic, :set_mimic_global}

  # the scattered spot is walkable: the snap echoes it back
  setup do
    Mimic.stub(Ms2ex.Navigation, :snap_to_floor, fn _map_id, pos -> pos end)
    :ok
  end

  @mob_metadata %{basic: %{friendly: 0, class: 0, level: 1}, stat: %{stats: %{health: 5}}}
  @npc_metadata %{basic: %{friendly: 1, class: 0, level: 1}, stat: %{stats: %{health: 5}}}
  @position %{x: 2700.0, y: -750.0, z: 1200.0}

  defp mob_npc(metadata \\ @mob_metadata),
    do: %Ms2ex.Types.Npc{id: 29_000_128, metadata: metadata}

  defp new_field_npc(npc, attrs \\ []) do
    FieldNpc.new(
      Map.merge(
        %{
          object_id: 1,
          spawn_point_id: 101,
          npc: npc,
          position: @position,
          rotation: nil,
          field: "topic"
        },
        Map.new(attrs)
      )
    )
  end

  test "a zero spawn_radius spawns the mob at its exact configured position" do
    field_npc = new_field_npc(mob_npc(), spawn_radius: 0.0)

    assert field_npc.position.x == @position.x
    assert field_npc.position.y == @position.y
  end

  test "an explicit spawn_radius of nil (no radius metadata) keeps the coarse spread" do
    field_npc = new_field_npc(mob_npc(), spawn_radius: nil)

    assert abs(field_npc.position.x - @position.x) <= 250
    assert abs(field_npc.position.y - @position.y) <= 250
  end

  test "a positive spawn_radius scatters the mob within that circle" do
    radius = 50.0

    field_npc = new_field_npc(mob_npc(), spawn_radius: radius, map_id: 999_999_999)

    distance =
      :math.sqrt(
        :math.pow(field_npc.position.x - @position.x, 2) +
          :math.pow(field_npc.position.y - @position.y, 2)
      )

    assert distance <= radius
  end

  test "open-world spawns with no spawn_radius key keep the coarse spread" do
    field_npc =
      new_field_npc(
        mob_npc(),
        spawn_point_id: nil,
        map_id: 999_999_999
      )

    # still within the legacy box jitter, but not pinned exactly on top of
    # the spawn point (statistically all but impossible to land exactly)
    assert abs(field_npc.position.x - @position.x) <= 250
    assert abs(field_npc.position.y - @position.y) <= 250
  end

  test "a friendly npc with a spawn radius scatters within its circle too" do
    radius = 50.0

    field_npc = new_field_npc(mob_npc(@npc_metadata), spawn_radius: radius, map_id: 999_999_999)

    distance =
      :math.sqrt(
        :math.pow(field_npc.position.x - @position.x, 2) +
          :math.pow(field_npc.position.y - @position.y, 2)
      )

    assert distance <= radius
  end
end
