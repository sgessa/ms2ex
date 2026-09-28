defmodule Ms2ex.FieldNpcIdleTest do
  use Ms2ex.DataCase, async: true

  # synthetic mesh-set binary (regenerable with the crate's gen_fixtures
  # binary): an open 40x40 floor
  @open File.read!("test/fixtures/navmesh/open.mset")

  alias Ms2ex.Managers.Field.Npc.Battle
  alias Ms2ex.Navigation
  alias Ms2ex.Types

  defp mob_metadata(overrides) do
    Map.merge(
      %{
        basic: %{friendly: 0, class: 0, level: 10},
        stat: %{stats: %{health: 1000, movement_speed: 100}},
        model: %{name: "TestMob"},
        capsule: %{radius: 50, height: 150},
        action: %{walk_speed: 100, run_speed: 300},
        distance: %{sight: 500, sight_height_up: 300, sight_height_down: 100},
        skill: []
      },
      Map.new(overrides)
    )
  end

  # a mob standing away from the mesh corner so random wander points land
  # inside the floor with room to spare
  defp idle_mob(metadata, map_id) do
    Types.FieldNpc.new(%{
      object_id: 50_000_003,
      spawn_point_id: 1,
      map_id: map_id,
      npc: Types.Npc.new(%{id: 22_000_000, metadata: metadata}),
      position: %Types.Coord{x: 1000, y: -1000, z: 0},
      rotation: %Types.Coord{x: 0, y: 0, z: 0},
      field: self(),
      spawn_radius: 0,
      next_target_scan_at: 0
    })
  end

  defp empty_field, do: %{players: %{}, player_positions: %{}}

  setup do
    stub_metadata(%{})
    :ok
  end

  test "a walk routine starts a wander leg toward a point inside the move area" do
    {map_id, xblock} = unique_map()
    {metadata, _} = stub_idle_world(map_id, xblock, [%{name: "Walk_A", probability: 10}])

    npc = idle_mob(metadata, map_id)

    # the first tick starts a stand; past the stand beat the walk routine
    # rolls and the leg begins
    {npc, []} = Battle.tick(npc, empty_field(), 0)
    refute npc.battle
    assert npc.idle.task == :stand

    {npc, []} = Battle.tick(npc, empty_field(), 1_100)
    assert %{mode: :wander} = npc.battle
    assert npc.idle == nil

    # the walk itself starts on the next tick
    {npc, []} = Battle.tick(npc, empty_field(), 1_300)
    assert npc.velocity != {0, 0, 0}

    # the goal is a walkable spot on the mesh: the random-point query picks
    # an area-weighted polygon touching the move-area circle, so the point
    # may sit on a polygon beyond its edge, but it stays on the floor
    goal = npc.battle.goal
    dx = goal.x - npc.origin.x
    dy = goal.y - npc.origin.y
    assert :math.sqrt(dx * dx + dy * dy) > 0
    assert Navigation.snap_to_floor(map_id, goal)
  end

  test "a wander leg walks its goal and hands the mob back to its idle routines" do
    {map_id, xblock} = unique_map()

    {metadata, _} =
      stub_idle_world(map_id, xblock, [%{name: "Run_A", probability: 10}], run_speed: 400)

    npc = idle_mob(metadata, map_id)
    {npc, []} = Battle.tick(npc, empty_field(), 0)
    {npc, []} = Battle.tick(npc, empty_field(), 1_100)
    assert %{mode: :wander} = npc.battle

    npc =
      Enum.reduce_while(1..400, npc, fn i, npc ->
        if npc.battle do
          {npc, _} = Battle.tick(npc, empty_field(), 1_100 + i * 200)
          {:cont, npc}
        else
          {:halt, npc}
        end
      end)

    refute npc.battle, "the leg should complete inside the simulated window"
    assert npc.idle.task == :stand
    assert npc.velocity == {0, 0, 0}
    # the mob actually moved from where it started
    dx = npc.position.x - npc.origin.x
    dy = npc.position.y - npc.origin.y
    assert :math.sqrt(dx * dx + dy * dy) > 100
  end

  test "a mob without a move area never wanders" do
    {map_id, xblock} = unique_map()

    {metadata, _} =
      stub_idle_world(map_id, xblock, [%{name: "Walk_A", probability: 10}], move_area: 0)

    npc = idle_mob(metadata, map_id)

    # several idle cycles in: still standing, never a battle
    {npc, []} = Battle.tick(npc, empty_field(), 0)

    npc =
      Enum.reduce(1..10, npc, fn i, npc ->
        {npc, []} = Battle.tick(npc, empty_field(), i * 1_000)
        refute npc.battle
        npc
      end)

    assert npc.idle.task == :stand
  end

  test "a bore routine plays once as an emote, then the mob stands" do
    {map_id, xblock} = unique_map()
    {metadata, _} = stub_idle_world(map_id, xblock, [%{name: "Bore_A", probability: 10}])

    npc = idle_mob(metadata, map_id)
    {npc, []} = Battle.tick(npc, empty_field(), 0)
    {npc, []} = Battle.tick(npc, empty_field(), 1_100)

    # the bore emote took over: the sequence plays with a revert deadline
    assert npc.emote
    assert npc.idle.task == :emote

    # past the emote's beat the idle routine settles back into a stand; the
    # animation itself reverts through the field's emote expiry
    {npc, []} = Battle.tick(npc, empty_field(), 1_100 + 1_600)
    assert npc.emote.revert_at <= 1_100 + 1_600
    assert npc.idle.task == :stand
  end

  test "a rooted mob rolls no wander legs" do
    {map_id, xblock} = unique_map()

    {metadata, _} =
      stub_idle_world(map_id, xblock, [%{name: "Walk_A", probability: 10}],
        walk_speed: 0,
        run_speed: 0
      )

    npc = idle_mob(metadata, map_id)

    npc =
      Enum.reduce(1..10, npc, fn i, npc ->
        {npc, []} = Battle.tick(npc, empty_field(), i * 1_000)
        refute npc.battle, "a mob with no locomotion must not start a wander leg"
        npc
      end)

    assert npc.idle.task == :stand
  end

  defp unique_map do
    suffix = System.unique_integer([:positive])
    {993_000_000 + suffix, "test_idle_#{suffix}"}
  end

  defp stub_idle_world(map_id, xblock, actions, opts \\ []) do
    action =
      %{
        walk_speed: Keyword.get(opts, :walk_speed, 100),
        run_speed: Keyword.get(opts, :run_speed, 300),
        move_area: Keyword.get(opts, :move_area, 500),
        actions: actions
      }

    metadata =
      mob_metadata(action: action)
      |> Map.put(:model, %{name: "TestMob"})

    stub_metadata(%{
      "map:#{map_id}" => %{x_block: xblock},
      "navmesh_bin:#{xblock}" => @open,
      # anikey docs key on the lowercased model name; declaring the keys
      # here also makes the atoms exist for Storage.Animations' to_existing_atom
      "animation:testmob" => %{
        sequences: %{
          Walk_A: %{id: 9},
          Run_A: %{id: 11},
          Idle_A: %{id: 10},
          Bore_A: %{id: 12, time: 1.5}
        }
      }
    })

    on_exit(fn -> :persistent_term.erase({:navmesh_native, xblock}) end)

    metadata = put_in(metadata, [:action], action)
    {metadata, nil}
  end
end
