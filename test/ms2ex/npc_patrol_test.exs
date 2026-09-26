defmodule Ms2ex.NpcPatrolTest do
  # advance_patrol is a pure state transition (npc in, npc out), so the
  # patrol ticks are driven directly without a field process. The tests
  # drive the waypoint failure paths on purpose, so their expected
  # warnings stay captured
  use Ms2ex.DataCase, async: false

  # the tests drive the waypoint failure paths on purpose, so their
  # expected warnings stay captured
  @moduletag capture_log: true

  alias Ms2ex.Managers.Field.Npc.Patrol
  alias Ms2ex.Types

  setup {Mimic, :set_mimic_global}

  setup do
    stub_metadata(%{
      "animation:cutscenenpc" => %{sequences: %{:Idle_A => 100, :Walk_A => 101, :Bore_B => 102}}
    })

    :ok
  end

  @l_shape File.read!("test/fixtures/navmesh/l_shape.mset")

  describe "walking the path" do
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

    test "a loop patrol cycles back to its first waypoint" do
      first = way_point(air: true, x: 500)
      second = way_point(air: true, x: 900)

      npc =
        patrolling_npc([first, second], last_at: 0, path: [second[:position]])
        |> Map.update!(:patrol, &Map.merge(&1, %{is_loop: true, index: 1}))

      npc = Patrol.advance_patrol(npc, 10_000)

      # the patrol survives and restarts from the first waypoint
      assert npc.patrol != nil
      assert npc.patrol.index == 0
      assert npc.patrol.path_index == 1
      assert npc.send_control? == true
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
      # authored waypoint appended by the route resolution
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

    test "a waypoint with an arrive animation plays it before the next leg departs" do
      first = way_point(air: true, arrive_animation: "Bore_B", arrive_animation_time: 2_000)
      second = way_point(air: true, x: 900)

      npc = patrolling_npc([first, second], last_at: 0, path: [first[:position]])

      # arrival at the first waypoint plays its arrive animation as an emote
      # and holds the next leg until the beat elapses
      npc = Patrol.advance_patrol(npc, 5_000)

      assert npc.patrol != nil
      assert npc.patrol.index == 1
      assert npc.patrol.depart_at == 7_000
      assert npc.animation == 102
      assert npc.emote.revert_at == 7_000
      assert npc.velocity == {0, 0, 0}

      # mid-beat: the npc holds the waypoint, emote still playing
      npc = Patrol.advance_patrol(npc, 6_000)

      assert npc.patrol.index == 1
      assert npc.animation == 102
      assert npc.emote
      assert npc.position == first.position

      # the beat elapses: the next leg departs and the emote clears
      npc = Patrol.advance_patrol(npc, 7_500)

      assert npc.emote == nil
      assert npc.patrol.depart_at == nil
      assert npc.patrol.index == 1
      assert npc.animation == 101
      assert npc.send_control? == true
    end

    test "a leg completed within the tick still turns the npc toward the waypoint" do
      # tiny authored legs reorient a npc between scripted beats (a
      # look-back nudge): the arrival tick must turn toward the waypoint
      tiny = way_point(air: false, x: 290)
      next = way_point(air: true, x: 900)

      npc = patrolling_npc([tiny, next], last_at: 0, path: [tiny[:position]])

      npc = Patrol.advance_patrol(npc, 5_000)

      assert npc.rotation.z == 90.0
      assert npc.velocity == {0, 0, 0}
      assert npc.patrol != nil
      assert npc.patrol.index == 1
      assert npc.send_control? == true
    end

    test "a next leg without a navmesh route stands the npc where it stopped" do
      first = way_point(air: true)
      ground = way_point(air: false)

      # arrived at the first (air) waypoint; the next leg targets a ground
      # waypoint on a map without a navmesh. The failed waypoint is the last
      # of a non-loop patrol, so the patrol ends with the npc standing where
      # it stopped instead of floating on
      npc = patrolling_npc([first, ground], last_at: 0, path: [first[:position]])

      npc = Patrol.advance_patrol(npc, 5_000)

      assert npc.patrol == nil
      assert npc.animation == 100
      assert npc.velocity == {0, 0, 0}
      assert npc.position == first.position
    end
  end

  describe "leg speeds" do
    test "a zero-speed gait falls back to the model's other gait" do
      # story models often author no run speed (run_speed 0): their cutscene
      # pacing comes from the patrol document, not the model
      npc = %Types.FieldNpc{
        object_id: 1,
        type: :npc,
        npc: %{
          id: 30_000_071,
          metadata: %{model: %{name: "CutsceneNpc"}, action: %{walk_speed: 120.0, run_speed: 0.0}}
        },
        position: %Types.Coord{x: 0, y: 0, z: 0},
        rotation: %Types.Coord{x: 0, y: 0, z: 0},
        animation: 101
      }

      # resolving the run gait to zero would root the npc mid-scene while
      # it keeps playing its run sequence
      assert Patrol.leg_speed(npc, "Run_A") == 120.0
      assert Patrol.leg_speed(npc, "Walk_A") == 120.0
    end
  end

  describe "unroutable legs" do
    test "a leg without a navmesh route is skipped and the patrol continues" do
      first = way_point(air: false)
      second = way_point(air: true)

      npc = patrolling_npc([first, second], last_at: 0, path: [path_target(0)])

      # the map has no navmesh, so the ground leg cannot start: the patrol
      # advances past the waypoint and holds the npc in its idle pose for a
      # beat instead of ending the patrol or walking a line that can float
      # above the terrain
      npc = Patrol.start_leg(npc, 5_000)

      assert npc.patrol != nil
      assert npc.patrol.index == 1
      assert npc.patrol.depart_at == 6_000
      assert npc.velocity == {0, 0, 0}
      assert npc.animation == 100
      assert npc.emote == nil

      # the beat elapses: the next leg departs toward the air waypoint
      npc = Patrol.advance_patrol(npc, 6_500)

      assert npc.patrol.path == [second[:position]]
      assert npc.patrol.path_index == 1
      assert npc.animation == 101
      assert npc.send_control? == true
    end

    test "a loop patrol keeps cycling past an unwalkable waypoint" do
      unroutable = way_point(air: false)
      reachable = way_point(air: true)

      npc =
        patrolling_npc([unroutable, reachable], last_at: 0, path: [reachable[:position]])
        |> Map.update!(:patrol, &Map.merge(&1, %{is_loop: true, index: 1}))

      # arriving at the reachable waypoint wraps the loop onto the unwalkable
      # one: the waypoint is skipped and held, the patrol keeps cycling
      npc = Patrol.advance_patrol(npc, 5_000)

      assert npc.patrol != nil
      assert npc.patrol.index == 1
      assert npc.patrol.depart_at == 6_000

      npc = Patrol.advance_patrol(npc, 6_500)

      assert npc.patrol != nil
      assert npc.patrol.path == [reachable[:position]]
      assert npc.animation == 101
    end

    test "the scripted-carry dummy walks an unroutable leg on the authored line" do
      ground = way_point(air: false)

      npc = patrolling_npc([ground], last_at: 0, despawn_on_finish?: true)

      npc = Patrol.start_leg(npc, 5_000)

      # the carry is choreographed client-side and must complete: the dummy
      # walks the authored straight line instead of skipping the waypoint
      assert npc.patrol != nil
      assert npc.patrol.path == [ground[:position]]
      assert npc.patrol.path_index == 1
      assert npc.animation == 101
      assert npc.send_control? == true
    end

    test "a waypoint whose approach animation the model cannot play is skipped" do
      first = way_point(air: true, approach_animation: "No_Such_Anim")
      second = way_point(air: true, x: 900)

      npc = patrolling_npc([first, second], last_at: 0)
      animations = Patrol.leg_animations(npc, [first, second])

      # the air leg has neither its approach animation nor the Fly_A
      # fallback: it carries nil instead of refusing the whole patrol
      assert animations == [nil, 101]

      npc = Map.update!(npc, :patrol, &%{&1 | animations: animations})

      # the leg has no resolvable sequence: the npc holds in its idle pose
      # while the patrol advances past the waypoint
      npc = Patrol.start_leg(npc, 5_000)

      assert npc.patrol != nil
      assert npc.patrol.index == 1
      assert npc.patrol.depart_at == 6_000
      assert npc.animation == 100

      npc = Patrol.advance_patrol(npc, 6_500)

      assert npc.patrol.path == [second[:position]]
      assert npc.animation == 101
    end
  end

  describe "move_npc attach" do
    setup do
      suffix = System.unique_integer([:positive])
      xblock = "test_patrol_#{suffix}"
      map_id = 980_000_000 + suffix

      stub_metadata(%{
        "animation:cutscenenpc" => %{sequences: %{:Idle_A => 100, :Walk_A => 101}},
        "map:#{map_id}" => %{x_block: xblock},
        "navmesh_bin:#{xblock}" => @l_shape
      })

      on_exit(fn ->
        :persistent_term.erase({:navmesh_native, xblock})
      end)

      %{map_id: map_id}
    end

    test "a patrol attaches past an unwalkable first waypoint", %{map_id: map_id} do
      # the L floor spans navmesh x/z 0..8; x 2000 is off the mesh while
      # client (500, -200) sits on the lower arm
      state = move_npc_state(map_id, [%{x: 2000, y: 0, z: 0}, %{x: 500, y: -200, z: 0}])

      state = Patrol.move_npc(state, 3, "story_path")
      npc = get_in(state, [:npcs, 7])

      # attaching never routes ahead: the patrol attaches with the unwalkable
      # waypoint skipped and the npc held in its idle pose
      assert npc.patrol != nil
      assert npc.patrol.index == 1
      assert npc.patrol.depart_at != nil
      assert npc.velocity == {0, 0, 0}

      # the beat elapses and the leg toward the walkable waypoint departs
      hold_until = npc.patrol.depart_at

      npc = Patrol.advance_patrol(npc, hold_until + 100)

      assert npc.patrol != nil
      assert length(npc.patrol.path) >= 2

      npc = Patrol.advance_patrol(npc, hold_until + 200)

      assert npc.velocity != {0, 0, 0}
    end

    test "an all-unwalkable patrol holds then ends without leaving the post", %{
      map_id: map_id
    } do
      state = move_npc_state(map_id, [%{x: 2000, y: 0, z: 0}, %{x: 2500, y: 0, z: 0}])

      state = Patrol.move_npc(state, 3, "story_path")
      npc = get_in(state, [:npcs, 7])

      assert npc.patrol != nil
      assert npc.patrol.index == 1

      # the last waypoint of the non-loop patrol fails to start: the patrol
      # ends and the npc keeps its post
      npc = Patrol.advance_patrol(npc, npc.patrol.depart_at + 100)

      assert npc.patrol == nil
      assert npc.animation == 100
      assert npc.position == %Types.Coord{x: 100, y: -100, z: 0}
    end
  end

  defp patrolling_npc(way_points, opts) do
    %Types.FieldNpc{
      object_id: 1,
      map_id: 999_999_999,
      type: :npc,
      npc: %{id: 30_000_071, metadata: %{model: %{name: "CutsceneNpc"}}},
      position: %Types.Coord{x: 0, y: 0, z: 0},
      rotation: %Types.Coord{x: 0, y: 0, z: 0},
      animation: 101,
      velocity: {30, 0, 0},
      send_control?: false,
      patrol: %{
        waypoints: way_points,
        animations: Keyword.get(opts, :animations, Enum.map(way_points, fn _ -> 101 end)),
        speeds: nil,
        index: Keyword.get(opts, :index, 0),
        speed: 500.0,
        last_at: Keyword.fetch!(opts, :last_at),
        despawn_on_finish?: Keyword.get(opts, :despawn_on_finish?, false),
        path: Keyword.get(opts, :path),
        path_index: 1
      }
    }
  end

  defp move_npc_state(map_id, positions) do
    way_points =
      Enum.map(positions, fn position ->
        %{id: "wp-#{position.x}", position: position, approach_animation: "Walk_A"}
      end)

    npc = %Types.FieldNpc{
      object_id: 7,
      map_id: map_id,
      type: :npc,
      spawn_point_id: 3,
      npc: %{id: 30_000_071, metadata: %{model: %{name: "CutsceneNpc"}}},
      position: %Types.Coord{x: 100, y: -100, z: 0},
      rotation: %Types.Coord{x: 0, y: 0, z: 0},
      animation: 101
    }

    patrol_doc = %{way_points: way_points, is_loop: false, speed: 0}

    %{npcs: %{7 => npc}, patrols: %{"story_path" => patrol_doc}}
  end

  # the straight authored line is the no-route fallback: the leg's path is
  # just the authored waypoint itself
  defp path_target(_index), do: %Types.Coord{x: 500, y: 0, z: 0}

  defp way_point(opts) do
    %{
      id: Keyword.get(opts, :id, "wp"),
      position: %Types.Coord{x: Keyword.get(opts, :x, 500), y: 0, z: 0},
      air_way_point: Keyword.get(opts, :air, false),
      approach_animation: Keyword.get(opts, :approach_animation, "Walk_A")
    }
    |> maybe_put(:arrive_animation, Keyword.get(opts, :arrive_animation))
    |> maybe_put(:arrive_animation_time, Keyword.get(opts, :arrive_animation_time))
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
