defmodule Ms2ex.FieldNpcSpawnPositionTest do
  use Ms2ex.DataCase, async: true

  alias Ms2ex.Types.FieldNpc

  @mob_metadata %{basic: %{friendly: 0, class: 0, level: 1}, stat: %{stats: %{health: 5}}}
  @npc_metadata %{basic: %{friendly: 1, class: 0, level: 1}, stat: %{stats: %{health: 5}}}
  @position %{x: 2700.0, y: -750.0, z: 1200.0}

  defp mob_npc(metadata \\ @mob_metadata),
    do: %Ms2ex.Types.Npc{id: 29_000_128, metadata: metadata}

  test "a zero spawn_radius spawns the mob at its exact configured position" do
    field_npc =
      FieldNpc.new(%{
        object_id: 1,
        spawn_point_id: 101,
        npc: mob_npc(),
        position: @position,
        rotation: nil,
        spawn_radius: 0.0,
        field: "topic"
      })

    assert field_npc.position.x == @position.x
    assert field_npc.position.y == @position.y
  end

  test "an explicit spawn_radius of nil (no radius metadata) keeps the coarse spread" do
    field_npc =
      FieldNpc.new(%{
        object_id: 1,
        spawn_point_id: 101,
        npc: mob_npc(),
        position: @position,
        rotation: nil,
        spawn_radius: nil,
        field: "topic"
      })

    assert abs(field_npc.position.x - @position.x) <= 250
    assert abs(field_npc.position.y - @position.y) <= 250
  end

  test "a positive spawn_radius scatters the mob within that circle" do
    radius = 50.0

    field_npc =
      FieldNpc.new(%{
        object_id: 1,
        spawn_point_id: 101,
        npc: mob_npc(),
        position: @position,
        rotation: nil,
        spawn_radius: radius,
        field: "topic"
      })

    distance =
      :math.sqrt(
        :math.pow(field_npc.position.x - @position.x, 2) +
          :math.pow(field_npc.position.y - @position.y, 2)
      )

    assert distance <= radius
  end

  test "open-world spawns with no spawn_radius key keep the coarse spread" do
    field_npc =
      FieldNpc.new(%{
        object_id: 1,
        spawn_point_id: nil,
        npc: mob_npc(),
        position: @position,
        rotation: nil,
        field: "topic"
      })

    # still within the legacy box jitter, but not pinned exactly on top of
    # the spawn point (statistically all but impossible to land exactly)
    assert abs(field_npc.position.x - @position.x) <= 250
    assert abs(field_npc.position.y - @position.y) <= 250
  end

  test "friendly npcs never get spawn-position jitter regardless of radius" do
    field_npc =
      FieldNpc.new(%{
        object_id: 1,
        spawn_point_id: 101,
        npc: mob_npc(@npc_metadata),
        position: @position,
        rotation: nil,
        spawn_radius: 999.0,
        field: "topic"
      })

    assert field_npc.position.x == @position.x
    assert field_npc.position.y == @position.y
  end
end
