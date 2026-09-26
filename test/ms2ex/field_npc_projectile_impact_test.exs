defmodule Ms2ex.FieldNpcProjectileImpactTest do
  # impact application is a pure state transition over the field state and
  # the character manager: the flight data arrives pre-resolved on the hit
  use Ms2ex.DataCase, async: false

  alias Ms2ex.Managers
  alias Ms2ex.Managers.Field.Npc
  alias Ms2ex.Schema
  alias Ms2ex.Types

  @character_id 918_274
  @object_id 4242
  @mob_object_id 50_000_004

  setup do
    character = %Schema.Character{
      id: @character_id,
      name: "Target",
      object_id: @object_id,
      map_id: 0,
      channel_id: 1,
      stats: %{
        health_max: 1000,
        health_cur: 1000,
        defense_cur: 10,
        physical_res_cur: 0,
        hp_regen_interval_cur: 3000
      }
    }

    {:ok, char_pid} = Managers.Character.start(character)
    on_exit(fn -> if Process.alive?(char_pid), do: GenServer.stop(char_pid) end)

    :ok
  end

  test "a straight shot lands when its flight reaches the victim" do
    # launch at the origin firing +x at 300 units/s: the victim stands in
    # the line 130 units out, inside the impact radius
    state =
      field_state(player_at: %Types.Coord{x: 130, y: 0, z: 0})
      |> put_in([:projectiles], %{{@mob_object_id, 1} => projectile()})

    state = Npc.advance_projectiles(state, 100)

    {:ok, character} = Managers.Character.call(@character_id, :lookup)
    assert character.stats.health_cur < 1000
    # the shot despawns on impact
    assert Map.get(state, :projectiles) == %{}
  end

  test "a straight shot dodges when the victim sidesteps off its line" do
    # the victim stands 250 units off the shot's line: the projectile flies
    # its full 600-unit flight and despawns without landing
    state =
      field_state(player_at: %Types.Coord{x: 30, y: 250, z: 0})
      |> put_in([:projectiles], %{{@mob_object_id, 1} => projectile()})

    state =
      Enum.reduce(1..25, state, fn i, state ->
        Npc.advance_projectiles(state, i * 100)
      end)

    {:ok, character} = Managers.Character.call(@character_id, :lookup)
    assert character.stats.health_cur == 1000
    assert Map.get(state, :projectiles) == %{}
  end

  test "a straight shot keeps flying until its flight runs out" do
    # the victim stands far off the line: the projectile advances along
    # its launch direction without landing and despawns at its max
    # distance
    state = field_state(player_at: %Types.Coord{x: 0, y: 5_000, z: 0})
    state = put_in(state, [:projectiles], %{{@mob_object_id, 1} => projectile()})

    state = Npc.advance_projectiles(state, 100)
    projectile = state.projectiles[{@mob_object_id, 1}]
    assert projectile.traveled == 30.0

    # the per-tick step clamp means the flight drains over several ticks
    state =
      Enum.reduce(2..25, state, fn i, state ->
        Npc.advance_projectiles(state, 100 + i * 100)
      end)

    assert Map.get(state, :projectiles) == %{}
  end

  test "a homing shot lands while its victim stays inside the attack's reach" do
    state =
      field_state(player_at: %Types.Coord{x: 250, y: 250, z: 0})

    hit = hit(arrow_overlap?: true)
    Npc.apply_projectile_impact(state, hit)

    {:ok, character} = Managers.Character.call(@character_id, :lookup)
    assert character.stats.health_cur < 1000
  end

  test "a homing shot whiffs once its victim left the attack's reach" do
    state =
      field_state(player_at: %Types.Coord{x: 5_000, y: 0, z: 0})

    hit = hit(arrow_overlap?: true)
    Npc.apply_projectile_impact(state, hit)

    {:ok, character} = Managers.Character.call(@character_id, :lookup)
    assert character.stats.health_cur == 1000
  end

  test "a projectile whiffs when its victim left the field" do
    state = %{
      field_state(player_at: %Types.Coord{x: 250, y: 0, z: 0})
      | players: %{}
    }

    hit = hit()
    Npc.apply_projectile_impact(state, hit)

    {:ok, character} = Managers.Character.call(@character_id, :lookup)
    assert character.stats.health_cur == 1000
  end

  test "the launch record direction is the world shot direction" do
    alias Ms2ex.Managers.Field.Npc

    # the client flies the projectile along the packet's world direction:
    # the launch record carries it through unchanged
    world = %Types.Coord{x: 0.6, y: -0.8, z: 0.0}
    assert Npc.launch_direction(world) == world
  end

  defp field_state(player_at: player_at) do
    %{
      npcs: %{},
      players: %{@character_id => @object_id},
      player_positions: %{@character_id => %{position: player_at}},
      tombstones: %{},
      npc_spawns: %{},
      topic: "projectile-impact-test",
      map_id: 0
    }
  end

  defp projectile do
    %{
      hit: hit(),
      origin: %Types.Coord{x: 0, y: 0, z: 0},
      direction: %Types.Coord{x: 1.0, y: 0.0, z: 0.0},
      velocity: 300.0,
      max_distance: 600.0,
      traveled: 0.0,
      victim_id: @character_id,
      launched_at: 0
    }
  end

  defp hit(overrides \\ []) do
    Map.merge(
      %{
        character_id: @character_id,
        caster_object_id: @mob_object_id,
        target_object_id: @object_id,
        skill_id: 4001,
        skill_level: 1,
        position: %Types.Coord{x: 0, y: 0, z: 0},
        range: 300.0,
        direction: %Types.Coord{x: 1.0, y: 0.0, z: 0.0},
        attack: 500,
        rate: 1.0,
        magic_path_id: 5065,
        arrow_overlap?: false,
        travel_ms: 8,
        flight: 250.0,
        server_tick: 0,
        attack_counter: 1
      },
      Map.new(overrides)
    )
  end
end
