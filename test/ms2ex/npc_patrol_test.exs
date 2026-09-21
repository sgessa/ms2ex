defmodule Ms2ex.NpcPatrolTest do
  # advance_patrol is a pure state transition (npc in, npc out), so the
  # patrol ticks are driven directly without a field process
  use Ms2ex.DataCase, async: false

  alias Ms2ex.Managers.Field.Npc.Patrol
  alias Ms2ex.Types

  setup {Mimic, :set_mimic_global}

  setup do
    stub_metadata(%{
      "animation:cutscenenpc" => %{sequences: %{:Idle_A => 100, :Walk_A => 101}}
    })

    :ok
  end

  test "arriving at an air waypoint finishes the patrol with the idle pose" do
    way_point = way_point(air: true)
    npc = patrolling_npc([way_point], last_at: 0, path: [way_point[:position]])

    npc = Patrol.advance_patrol(npc, 5_000)

    assert npc.patrol == nil
    assert npc.velocity == {0, 0, 0}
    assert npc.animation == 100
    assert npc.send_control? == true
    assert npc.position == %Types.Coord{x: 500, y: 0, z: 0}
  end

  test "a leg without a navmesh route fails to start" do
    # the map has no navmesh, so find_path cannot route to the waypoint:
    # start_leg reports the error and the caller leaves the npc standing
    # (the reference's PathTo failure handling) instead of walking a line
    # that can float above the terrain
    npc = patrolling_npc([way_point(air: false)], last_at: 0, path: [path_target(0)])

    assert Patrol.start_leg(npc, npc.patrol) == :error
  end

  test "a leg mid-path keeps walking toward the current path point" do
    npc = patrolling_npc([way_point(air: false)], last_at: 5_000, path: [path_target(0)])

    npc = Patrol.advance_patrol(npc, 5_000)

    assert npc.patrol != nil
    assert npc.patrol.index == 0
    assert npc.position == %Types.Coord{x: 0.5, y: 0, z: 0}
    assert npc.velocity != {0, 0, 0}
    assert npc.send_control? == true
  end

  test "mesh path points are walked before the authored waypoint" do
    way_point = way_point(air: false)
    corner = %Types.Coord{x: 250, y: 0, z: 0}

    # the leg path: the npc's own position, a funnel corner, then the
    # authored waypoint appended by start_leg
    npc =
      patrolling_npc([way_point],
        last_at: 0,
        path: [
          %Types.Coord{x: 0, y: 0, z: 0},
          corner,
          way_point[:position]
        ]
      )

    # first tick reaches the funnel corner and continues the leg
    npc = Patrol.advance_patrol(npc, 5_000)

    assert npc.patrol != nil
    assert npc.patrol.path_index == 2
    assert npc.position == corner
    assert npc.send_control? == true

    # second tick consumes the path and finishes on the authored waypoint
    npc = Patrol.advance_patrol(npc, 10_000)

    assert npc.patrol == nil
    assert npc.animation == 100
    assert npc.velocity == {0, 0, 0}
    assert npc.position == %Types.Coord{x: 500, y: 0, z: 0}
  end

  test "the walk continues to the next waypoint after an intermediate arrival" do
    first = way_point(air: true)
    second = %{way_point(air: true) | position: %Types.Coord{x: 1000, y: 0, z: 0}}

    npc = patrolling_npc([first, second], last_at: 0, path: [first[:position]])

    npc = Patrol.advance_patrol(npc, 5_000)

    assert npc.patrol.index == 1
    assert npc.position == first.position
    assert npc.send_control? == true

    npc = Patrol.advance_patrol(npc, 10_000)

    assert npc.patrol == nil
    assert npc.animation == 100
    assert npc.velocity == {0, 0, 0}
    assert npc.position == second.position
  end

  test "a next leg without a navmesh route stands the npc where it stopped" do
    ground = way_point(air: false)
    first = way_point(air: true)

    # arrived at the first waypoint; the next leg targets a ground waypoint
    # on a map without a navmesh, so its route cannot resolve
    npc = patrolling_npc([first, ground], last_at: 0, path: [first[:position]])

    # the walk to the first (air) waypoint completes; the next leg targets a
    # ground waypoint on a map without a navmesh, so its route cannot
    # resolve — the npc stands where it stopped instead of floating on
    npc = Patrol.advance_patrol(npc, 5_000)

    assert npc.patrol == nil
    assert npc.animation == 100
    assert npc.velocity == {0, 0, 0}
    assert npc.position == first.position
  end

  defp patrolling_npc(way_points, opts) do
    %Types.FieldNpc{
      object_id: 1,
      map_id: 999_999_999,
      type: :npc,
      npc: %{metadata: %{model: %{name: "CutsceneNpc"}}},
      position: %Types.Coord{x: 0, y: 0, z: 0},
      rotation: %Types.Coord{x: 0, y: 0, z: 0},
      animation: 101,
      velocity: {30, 0, 0},
      send_control?: false,
      patrol:
        Map.merge(
          %{
            waypoints: way_points,
            animations: Enum.map(way_points, fn _ -> 101 end),
            speeds: nil,
            index: 0,
            speed: 500.0,
            last_at: Keyword.fetch!(opts, :last_at),
            despawn_on_finish?: false,
            path: Keyword.fetch!(opts, :path),
            path_index: 1
          },
          %{}
        )
    }
  end

  # the straight authored line is the no-route fallback: the leg's path is
  # just the authored waypoint itself
  defp path_target(_index), do: %Types.Coord{x: 500, y: 0, z: 0}

  defp way_point(opts) do
    %{
      position: %Types.Coord{x: 500, y: 0, z: 0},
      air_way_point: Keyword.get(opts, :air, false),
      approach_animation: "Walk_A"
    }
  end
end
