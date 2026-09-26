defmodule Ms2ex.FieldNpcProjectileImpactTest do
  # impact application is a pure state transition over the field state and
  # the character manager: the flight data arrives pre-resolved on the hit
  use Ms2ex.DataCase, async: false

  alias Ms2ex.Managers
  alias Ms2ex.Managers.Field.Npc
  alias Ms2ex.Managers.Field.Npc.Battle
  alias Ms2ex.Schema
  alias Ms2ex.Types

  @counter_mob_metadata %{
    basic: %{friendly: 0, class: 0, level: 10},
    stat: %{stats: %{health: 1000, movement_speed: 100}},
    model: %{name: "TestMob"},
    capsule: %{radius: 50, height: 150},
    action: %{walk_speed: 100, run_speed: 300},
    distance: %{sight: 500, sight_height_up: 300, sight_height_down: 100},
    skill: []
  }

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

  test "the control sequence counter only moves when the sequence changes" do
    # an idle mob with no battle and no idle routines: its control
    # broadcasts must hold the counter steady across periodic ticks and
    # only bump it when the animation itself changes
    npc =
      Types.FieldNpc.new(%{
        object_id: @mob_object_id,
        spawn_point_id: 1,
        map_id: 0,
        npc: Types.Npc.new(%{id: 22_000_000, metadata: @counter_mob_metadata}),
        position: %Types.Coord{x: 0, y: 0, z: 0},
        rotation: %Types.Coord{x: 0, y: 0, z: 0},
        field: self(),
        spawn_radius: 0,
        next_target_scan_at: 9_999_999_999_999,
        animation: 7,
        idle: %{task: :stand, until: 9_999_999_999_999}
      })

    state = %{
      field_state(player_at: %Types.Coord{x: 5_000, y: 0, z: 0})
      | npcs: %{npc.object_id => npc}
    }

    state = Npc.tick(state)
    npc = state.npcs[@mob_object_id]
    counter = npc.seq_counter
    assert npc.sent_animation == npc.animation

    # pin the sequence across a periodic broadcast (the last control aged
    # past the interval): the counter holds
    state =
      put_in(state, [:npcs, @mob_object_id, Access.key!(:animation)], 7)
      |> put_in([:npcs, @mob_object_id, Access.key!(:idle_sequence_id)], 7)
      |> put_in([:npcs, @mob_object_id, Access.key!(:sent_animation)], 7)
      |> put_in([:npcs, @mob_object_id, Access.key!(:last_control_at)], -1_000_000)

    state = Npc.tick(state)
    assert state.npcs[@mob_object_id].seq_counter == counter

    # a sequence change bumps it
    state =
      state
      |> put_in([:npcs, @mob_object_id, Access.key!(:animation)], 9)
      |> put_in([:npcs, @mob_object_id, Access.key!(:idle_sequence_id)], 9)
      |> put_in([:npcs, @mob_object_id, Access.key!(:last_control_at)], -1_000_000)

    state = Npc.tick(state)
    assert state.npcs[@mob_object_id].seq_counter == counter + 1
  end

  test "a casting mob's state-change control still broadcasts mid-swing" do
    # the cast start sets send_control?: the swing-pinning control must go
    # out even while the periodic stream is suppressed, or the client keeps
    # extrapolating the mob's last chase velocity off the map
    npc =
      Types.FieldNpc.new(%{
        object_id: @mob_object_id,
        spawn_point_id: 1,
        map_id: 0,
        npc: Types.Npc.new(%{id: 22_000_000, metadata: @counter_mob_metadata}),
        position: %Types.Coord{x: 0, y: 0, z: 0},
        rotation: %Types.Coord{x: 0, y: 0, z: 0},
        field: self(),
        spawn_radius: 0,
        next_target_scan_at: 9_999_999_999_999,
        animation: 7,
        idle: %{task: :stand, until: 9_999_999_999_999}
      })

    npc = Battle.aggro(npc, %Schema.Character{id: @character_id, object_id: @object_id}, 0)

    npc = %{
      npc
      | battle: %{
          npc.battle
          | cast: %{
              started_at: 0,
              hit_at: 9_999_999_999_999,
              end_at: 9_999_999_999_999,
              motion_switches: []
            }
        },
        send_control?: true,
        velocity: {0, 0, 0}
    }

    state = %{
      field_state(player_at: %Types.Coord{x: 5_000, y: 0, z: 0})
      | npcs: %{npc.object_id => npc}
    }

    state = Npc.tick(state)

    # the control went out: the counter moved and the broadcast aged
    broadcast = state.npcs[@mob_object_id]
    assert broadcast.seq_counter == 1
    assert broadcast.last_control_at > 0
    assert broadcast.send_control? == false
  end

  test "an on-hit explosion cube damages every player standing in it" do
    # the bomb's effect skill: 0.8 rate, a 150-radius cube
    stub_metadata(%{
      "skill:40214002" => %{
        levels: %{
          "1" => %{
            motions: [
              %{
                attacks: [
                  %{
                    damage: %{rate: 0.8, value: 0},
                    range: %{distance: 150.0, height: 200.0}
                  }
                ]
              }
            ]
          }
        }
      }
    })

    # the bomb landed at the origin: the player stands inside the cube
    state = field_state(player_at: %Types.Coord{x: 100, y: 0, z: 0})

    payload = %{
      hit: hit(),
      center: %Types.Coord{x: 0, y: 0, z: 0},
      skill_id: 40_214_002,
      level: 1
    }

    Npc.apply_skill_explosion(payload, state)

    {:ok, character} = Managers.Character.call(@character_id, :lookup)
    assert character.stats.health_cur < 1000
  end

  test "an on-hit explosion misses players outside its cube" do
    stub_metadata(%{
      "skill:40214002" => %{
        levels: %{
          "1" => %{
            motions: [
              %{
                attacks: [
                  %{
                    damage: %{rate: 0.8, value: 0},
                    range: %{distance: 150.0, height: 200.0}
                  }
                ]
              }
            ]
          }
        }
      }
    })

    state = field_state(player_at: %Types.Coord{x: 5_000, y: 0, z: 0})

    payload = %{
      hit: hit(),
      center: %Types.Coord{x: 0, y: 0, z: 0},
      skill_id: 40_214_002,
      level: 1
    }

    Npc.apply_skill_explosion(payload, state)

    {:ok, character} = Managers.Character.call(@character_id, :lookup)
    assert character.stats.health_cur == 1000
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

    hit = hit(look_at_type: 1)
    Npc.apply_projectile_impact(state, hit)

    {:ok, character} = Managers.Character.call(@character_id, :lookup)
    assert character.stats.health_cur < 1000
  end

  test "a homing shot whiffs once its victim left the attack's reach" do
    state =
      field_state(player_at: %Types.Coord{x: 5_000, y: 0, z: 0})

    hit = hit(look_at_type: 1)
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
        look_at_type: 0,
        travel_ms: 8,
        flight: 250.0,
        server_tick: 0,
        attack_counter: 1
      },
      Map.new(overrides)
    )
  end
end
