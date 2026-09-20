defmodule Ms2ex.FieldNpcBattleTest do
  use Ms2ex.DataCase, async: true

  alias Ms2ex.Managers.Field.Npc.Battle
  alias Ms2ex.Types

  @sight 500
  @last_sight 2000

  defp mob_metadata(overrides \\ []) do
    Map.merge(
      %{
        basic: %{friendly: 0, class: 0, level: 10},
        stat: %{stats: %{health: 1000, movement_speed: 100}},
        model: %{name: "TestMob"},
        capsule: %{radius: 50, height: 150},
        action: %{walk_speed: 100, run_speed: 300},
        distance: distance_metadata(),
        skill: []
      },
      Map.new(overrides)
    )
  end

  defp distance_metadata(overrides \\ []) do
    Map.merge(
      %{
        sight: @sight,
        sight_height_up: 300,
        sight_height_down: 100,
        last_sight_radius: @last_sight,
        last_sight_height_up: 400,
        last_sight_height_down: 200
      },
      Map.new(overrides)
    )
  end

  defp friendly_metadata do
    %{basic: %{friendly: 1, class: 0, level: 1}, stat: %{stats: %{health: 100}}}
  end

  defp mob(overrides \\ []) do
    metadata = mob_metadata()

    base = %{
      object_id: 50_000_001,
      spawn_point_id: 1,
      npc: Types.Npc.new(%{id: 22_000_000, metadata: metadata}),
      position: %Types.Coord{x: 0, y: 0, z: 0},
      rotation: %Types.Coord{x: 0, y: 0, z: 0},
      field: self(),
      # deterministic position: zero radius spawns exactly where placed
      spawn_radius: 0,
      # due immediately unless a test overrides it
      next_target_scan_at: 0
    }

    Types.FieldNpc.new(Map.merge(base, Map.new(overrides)))
  end

  defp mob_with_metadata(metadata, overrides \\ []) do
    overrides
    |> Keyword.put(:npc, Types.Npc.new(%{id: 22_000_000, metadata: metadata}))
    |> mob()
  end

  defp friendly_npc do
    metadata = friendly_metadata()

    Types.FieldNpc.new(%{
      object_id: 50_000_002,
      spawn_point_id: 2,
      npc: Types.Npc.new(%{id: 11_000_000, metadata: metadata}),
      position: %Types.Coord{x: 0, y: 0, z: 0},
      rotation: %Types.Coord{x: 0, y: 0, z: 0},
      field: self()
    })
  end

  # the field tracks players by character id -> object id plus their live
  # synced positions
  defp field_with_player_at(x, y, z \\ 0.0) do
    position = %Types.Coord{x: x, y: y, z: z}
    %{players: %{1 => 900}, player_positions: %{1 => %{position: position, job_code: nil}}}
  end

  setup do
    stub_metadata(%{})
    :ok
  end

  test "friendly npcs never engage" do
    npc = friendly_npc()
    state = field_with_player_at(100, 100)

    assert {npc2, []} = Battle.tick(npc, state, 10_000)
    assert npc2 == npc
  end

  test "a player inside the sight band gets engaged by the proximity scan" do
    npc = mob()
    state = field_with_player_at(300, 0)

    {npc, _} = Battle.tick(npc, state, 10_000)
    assert npc.battle
    assert npc.battle.target_id == 1
    assert npc.battle.target_object_id == 900
    assert npc.send_control?
  end

  test "a player outside the sight band is not engaged" do
    npc = mob()
    state = field_with_player_at(@sight + 100, 0)

    {npc, _} = Battle.tick(npc, state, 10_000)
    refute npc.battle
    assert npc.next_target_scan_at > 10_000
  end

  test "the scan respects the sight height band" do
    metadata = mob_metadata(distance: distance_metadata(sight_height_up: 50))
    npc = mob_with_metadata(metadata)

    # player 100 units above the mob: outside the 50-unit up band
    state = field_with_player_at(100, 0, 100.0)

    refute elem(Battle.tick(npc, state, 10_000), 0).battle
  end

  test "an engaged mob drops a target that left the field" do
    npc = aggroed_mob()
    empty_state = %{players: %{}, player_positions: %{}}

    {npc, _} = Battle.tick(npc, empty_state, 10_000)
    refute npc.battle
    assert npc.velocity == {0, 0, 0}
    assert npc.send_control?
  end

  test "an engaged mob drops a target beyond the last-sight radius" do
    npc = aggroed_mob()
    state = field_with_player_at(@last_sight + 100, 0)

    refute elem(Battle.tick(npc, state, 10_000), 0).battle
  end

  test "hit-aggro holds a target beyond last-sight for the engagement window" do
    npc = mob()
    state = field_with_player_at(9_999, 0)

    # sniped from far outside sight: the attacker is held for 5s
    npc = Battle.aggro(npc, %Ms2ex.Schema.Character{id: 1, object_id: 900}, 0)
    assert elem(Battle.tick(npc, state, 1_000), 0).battle

    # once the window passes, the normal last-sight drop applies
    refute elem(Battle.tick(npc, state, 6_000), 0).battle
  end

  test "a scan-acquired target drops on leaving the band with no hold window" do
    npc = mob()
    state = field_with_player_at(300, 0)

    # engaged by the proximity scan at now = 10_000
    {npc, _} = Battle.tick(npc, state, 10_000)
    assert npc.battle

    # the player escapes the last-sight band: dropped immediately, no hold
    escaped = field_with_player_at(@last_sight + 100, 0)
    refute elem(Battle.tick(npc, escaped, 10_060), 0).battle
  end

  test "the scan deadline seeds from the tick base, not a constant" do
    # deadlines must live on Ms2ex.sync_ticks/0's normalized base: a
    # constant 0 compared against the raw clock never fires (the raw BEAM
    # base can sit below zero), which silently killed sight aggro
    metadata = mob_metadata()

    npc =
      Types.FieldNpc.new(%{
        object_id: 50_000_050,
        spawn_point_id: 1,
        npc: Types.Npc.new(%{id: 22_000_000, metadata: metadata}),
        position: %Types.Coord{x: 0, y: 0, z: 0},
        rotation: %Types.Coord{x: 0, y: 0, z: 0},
        field: self(),
        spawn_radius: 0
      })

    now = Ms2ex.sync_ticks()

    assert npc.next_target_scan_at != 0
    assert npc.next_target_scan_at >= now - 10
  end

  test "an engaged mob keeps a target that stays inside the last-sight radius" do
    npc = aggroed_mob()
    state = field_with_player_at(@last_sight - 100, 0)

    assert elem(Battle.tick(npc, state, 10_000), 0).battle
  end

  test "hit-aggro engages the attacker immediately" do
    npc = mob()
    attacker = %Ms2ex.Schema.Character{id: 7, object_id: 700, name: "Testy"}

    npc = Battle.aggro(npc, attacker, 10_000)
    assert npc.battle
    assert npc.battle.target_id == 7
    assert npc.battle.target_object_id == 700
    assert npc.send_control?
  end

  test "hit-aggro ignores dead mobs and friendly npcs" do
    attacker = %Ms2ex.Schema.Character{id: 7, object_id: 700}

    dead = %{mob() | dead?: true}
    assert Battle.aggro(dead, attacker, 10_000).battle == nil

    assert Battle.aggro(friendly_npc(), attacker, 10_000).battle == nil
  end

  test "chasing closes distance over ticks and stops inside the stop range" do
    {map_id, xblock} = unique_map()
    stub_navmesh(xblock, map_id)

    # mob at the mesh corner, player 1500 units east: the mob runs along the
    # flat mesh and stops inside its melee stop range (capsule radius 50 + 80)
    npc = mob(map_id: map_id)
    state = field_with_player_at(1500, 0)

    npc = Battle.aggro(npc, %Ms2ex.Schema.Character{id: 1, object_id: 900}, 0)

    {npc, _state} =
      Enum.reduce(1..400, {npc, state}, fn i, {npc, state} ->
        {npc, hits} = Battle.tick(npc, state, i * 100)
        # the second element is always the list of hit events, even on
        # mid-path ticks that only advance the run
        assert is_list(hits)
        {npc, state}
      end)

    assert npc.battle
    assert npc.position.x > 1000, "mob should have crossed most of the distance"

    distance = 1500 - npc.position.x
    assert distance >= 0, "mob should not walk through its target"
    assert distance <= npc.battle.stop_range * 1.5
    assert npc.velocity == {0, 0, 0}
  end

  test "a chasing mob never stands while clearly out of range" do
    {map_id, xblock} = unique_map()
    stub_navmesh(xblock, map_id)

    npc = mob(map_id: map_id)
    npc = Battle.aggro(npc, %Ms2ex.Schema.Character{id: 1, object_id: 900}, 0)

    # the player hops back and forth across the mesh; whenever the mob is
    # clearly outside its stop range (past the resume margin) it must be
    # moving — a stand tick mid-chase makes the client flicker the walk
    # animation
    {npc, stutter_ticks} =
      Enum.reduce_while(1..120, {npc, 0}, fn i, {npc, stutter} ->
        player_x = if rem(i, 10) < 5, do: 3000, else: 1000
        state = field_with_player_at(player_x, -i * 20)
        {npc, _hits} = Battle.tick(npc, state, i * 100)

        # the mob may leash home mid-test; that is not a stand
        if npc.battle == nil do
          {:halt, {npc, stutter}}
        else
          player = state.player_positions[1].position

          d2 =
            :math.pow(npc.position.x - player.x, 2) +
              :math.pow(npc.position.y - player.y, 2)

          out_of_range? = d2 > :math.pow(npc.battle.stop_range + 60, 2)

          stutter =
            if out_of_range? and npc.velocity == {0, 0, 0} do
              stutter + 1
            else
              stutter
            end

          {:cont, {npc, stutter}}
        end
      end)

    assert stutter_ticks == 0,
           "mob stood #{inspect(stutter_ticks)} ticks while clearly out of range"
  end

  test "a mob leashes home when dragged beyond its last-sight from spawn" do
    {map_id, xblock} = unique_map()
    stub_navmesh(xblock, map_id)

    # the player stands where the mob cannot be dragged past its leash
    # (last_sight 2000 from origin) without dropping aggro
    npc = mob(map_id: map_id)
    npc = Battle.aggro(npc, %Ms2ex.Schema.Character{id: 1, object_id: 900}, 0)

    chase_state = field_with_player_at(2300, 0)

    {npc, _} =
      Enum.reduce(1..150, {npc, chase_state}, fn i, {npc, state} ->
        {npc, _hits} = Battle.tick(npc, state, i * 100)
        {npc, state}
      end)

    # the mob turned back before reaching the player
    assert npc.position.x < 2300 - 500

    case npc.battle do
      %{mode: :return} = battle ->
        assert battle.goal == %Types.Coord{x: 0.0, y: 0.0, z: 0.0}

      nil ->
        # already walked all the way home
        assert npc.position.x < 100
    end
  end

  test "a mob gives up on an unreachable target and walks home" do
    {map_id, xblock} = unique_map()

    # main island 0..4000 plus a detached island at 6000..6400
    verts =
      mesh_verts([
        {0, 0, 0},
        {40, 0, 0},
        {40, 0, 40},
        {0, 0, 40},
        {60, 0, 0},
        {64, 0, 0},
        {64, 0, 40},
        {60, 0, 40}
      ])

    doc = %{tiles: [%{verts: verts, polys: [[0, 1, 2, 3], [4, 5, 6, 7]]}]}

    stub_metadata(%{
      "map:#{map_id}" => %{x_block: xblock},
      "navmesh:#{xblock}" => doc
    })

    on_exit(fn -> :persistent_term.erase({:navgraph, xblock}) end)

    # the mob's home is the main island but it stands near its edge; the
    # player is on the detached island, inside last-sight but unreachable
    npc =
      mob(
        map_id: map_id,
        position: %Types.Coord{x: 3900, y: 0, z: 0},
        # dragged away from home before the fight
        origin: %Types.Coord{x: 0, y: 0, z: 0}
      )

    npc = Battle.aggro(npc, %Ms2ex.Schema.Character{id: 1, object_id: 900}, 0)
    unreachable = field_with_player_at(6200, 0)

    # still trying during the grace period
    {npc, _} = Battle.tick(npc, unreachable, 500)
    assert npc.battle

    # grace period over: gives up and walks home
    {npc, _} =
      Enum.reduce(6..400, {npc, nil}, fn i, {npc, _} ->
        {npc, _hits} = Battle.tick(npc, unreachable, i * 100)
        {npc, nil}
      end)

    assert npc.battle == nil, "mob should have given up and arrived home"
    assert npc.position.x < 400
  end

  test "a mob in stop range swings at its target on cooldown" do
    {map_id, xblock} = unique_map()
    stub_navmesh(xblock, map_id)

    # skill metadata: a single swing with a 300-unit range and a 1s cooldown
    stub_metadata(%{
      "skill:4001" => %{
        levels: %{
          "1" => %{
            cooldown_time: 1.0,
            motions: [
              %{
                motion_property: %{sequence_name: "Attack_001_A"},
                attacks: [%{range: %{distance: 300.0}, damage: %{rate: 2.0, value: 0}}]
              }
            ]
          }
        }
      }
    })

    metadata =
      mob_metadata(
        skill: [%{id: 4001, level: 1}],
        stat: %{stats: %{health: 1000, physical_atk: 500}}
      )

    npc = mob_with_metadata(metadata, map_id: map_id)

    # player stands within the 130-unit stop range
    state = field_with_player_at(100, 0)
    {npc, _} = Battle.tick(npc, state, 100)

    assert %{mode: :chase} = battle = npc.battle
    refute battle.cast, "the tick that engages does not swing yet"

    # the next tick starts the swing
    {npc, _} = Battle.tick(npc, state, 200)
    assert %{skill_id: 4001, hit_done?: false} = npc.battle.cast

    # past the windup: the swing resolves — the hit event is queued, the
    # cast is cleared and the cooldown gates the next swing
    {npc, _} = Battle.tick(npc, state, 700)
    assert %{character_id: 1, attack: 500, rate: 2.0, skill_id: 4001} = npc.battle.hit_event
    assert npc.battle.cast == nil
    assert npc.battle.next_attack_at >= 700

    # past the cast end: cooldown gates the next swing
    {npc, _} = Battle.tick(npc, state, 1_300)
    assert npc.battle.cast == nil
    assert npc.battle.next_attack_at >= 1_300

    refute elem(Battle.tick(npc, state, 1_350), 0).battle.cast
    assert elem(Battle.tick(npc, state, 2_400), 0).battle.cast
  end

  test "the swing whiffs when the target leaves range before the hit lands" do
    {map_id, xblock} = unique_map()
    stub_navmesh(xblock, map_id)

    metadata = mob_metadata(skill: [%{id: 4001, level: 1}])
    npc = mob_with_metadata(metadata, map_id: map_id)
    npc = Battle.aggro(npc, %Ms2ex.Schema.Character{id: 1, object_id: 900}, 0)

    {npc, _} = Battle.tick(npc, field_with_player_at(100, 0), 100)

    # the player teleports far away before the windup completes
    far_state = field_with_player_at(3_000, 0)
    {npc, _} = Battle.tick(npc, far_state, 700)

    hit_event = npc.battle && npc.battle.hit_event
    assert hit_event == nil
  end

  test "no navmesh on the map: the mob engages but holds position" do
    npc = mob()
    state = field_with_player_at(300, 0)

    npc = Battle.aggro(npc, %Ms2ex.Schema.Character{id: 1, object_id: 900}, 0)
    x_before = npc.position.x
    {npc, _} = Battle.tick(npc, state, 1_000)

    assert npc.battle
    assert npc.battle.path == nil
    assert npc.velocity == {0, 0, 0}
    assert npc.position.x == x_before
  end

  test "a displaced mob walks home and heals after losing its target" do
    {map_id, xblock} = unique_map()
    stub_navmesh(xblock, map_id)

    npc = mob(map_id: map_id)
    npc = Battle.aggro(npc, %Ms2ex.Schema.Character{id: 1, object_id: 900}, 0)

    # chase the player far from home
    chase_state = field_with_player_at(1500, 0)

    {npc, _} =
      Enum.reduce(1..60, {npc, chase_state}, fn i, {npc, state} ->
        {npc, _hits} = Battle.tick(npc, state, i * 100)
        {npc, state}
      end)

    assert npc.position.x > 800, "mob should have left its spawn area"

    # wound it and tag it before the target vanishes
    npc =
      npc
      |> Map.put(:stats, put_in(npc.stats, [:health, :current], 500))
      |> Map.put(:damage_dealers, %{1 => :deal})
      |> Map.put(:first_attacker, 1)
      |> Map.put(:last_attacker, 1)

    # the player leaves the field: the mob switches to walking home
    {npc, _} = Battle.tick(npc, %{players: %{}, player_positions: %{}}, 61 * 100)
    assert %{mode: :return} = npc.battle
    assert npc.battle.goal == %Types.Coord{x: 0.0, y: 0.0, z: 0.0}

    # and it arrives home, healed, tags cleared
    {npc, _} =
      Enum.reduce(62..400, {npc, nil}, fn i, {npc, _} ->
        {npc, _hits} = Battle.tick(npc, %{players: %{}, player_positions: %{}}, i * 100)
        {npc, nil}
      end)

    assert npc.battle == nil, "mob should go idle once home"
    assert npc.position.x <= 60 + 10
    assert npc.stats.health.current == npc.stats.health.total
    assert npc.damage_dealers == %{}
    assert npc.first_attacker == nil
    assert npc.last_attacker == nil
  end

  test "an undisplaced mob goes straight idle on disengage" do
    npc = mob()
    npc = Battle.aggro(npc, %Ms2ex.Schema.Character{id: 1, object_id: 900}, 0)

    # the target disappears while the mob never left home
    {npc, _} = Battle.tick(npc, %{players: %{}, player_positions: %{}}, 6_000)

    assert npc.battle == nil
  end

  test "a returning mob re-aggros when the player attacks it" do
    {map_id, xblock} = unique_map()
    stub_navmesh(xblock, map_id)

    npc = mob(map_id: map_id)
    npc = Battle.aggro(npc, %Ms2ex.Schema.Character{id: 1, object_id: 900}, 0)

    chase_state = field_with_player_at(1500, 0)

    {npc, _} =
      Enum.reduce(1..60, {npc, chase_state}, fn i, {npc, state} ->
        {npc, _hits} = Battle.tick(npc, state, i * 100)
        {npc, state}
      end)

    # target vanishes -> starts walking home
    {npc, _} = Battle.tick(npc, %{players: %{}, player_positions: %{}}, 61 * 100)
    assert %{mode: :return} = npc.battle

    # the player attacks it mid-route: back on the chase
    npc = Battle.aggro(npc, %Ms2ex.Schema.Character{id: 1, object_id: 900}, 62 * 100)
    {npc, _} = Battle.tick(npc, chase_state, 62 * 100 + 50)

    assert %{mode: :chase} = npc.battle
    assert npc.battle.target_id == 1
  end

  # -- helpers ------------------------------------------------------------------

  defp aggroed_mob do
    npc = mob()
    npc = Battle.aggro(npc, %Ms2ex.Schema.Character{id: 1, object_id: 900}, 0)
    %{npc | battle: %{npc.battle | stop_range: 120.0}}
  end

  defp unique_map do
    suffix = System.unique_integer([:positive])
    {991_000_000 + suffix, "test_chase_#{suffix}"}
  end

  # a flat 40x40 navmesh quad (navmesh meters) for chase movement
  defp stub_navmesh(xblock, map_id) do
    verts = mesh_verts([{0, 0, 0}, {40, 0, 0}, {40, 0, 40}, {0, 0, 40}])
    doc = %{tiles: [%{verts: verts, polys: [[0, 1, 2, 3]]}]}

    stub_metadata(%{
      "map:#{map_id}" => %{x_block: xblock},
      "navmesh:#{xblock}" => doc
    })

    on_exit(fn -> :persistent_term.erase({:navgraph, xblock}) end)
    :ok
  end

  defp mesh_verts(points) do
    Enum.reduce(points, <<>>, fn {x, y, z}, acc ->
      acc <> <<x::little-float-32, y::little-float-32, z::little-float-32>>
    end)
  end
end
