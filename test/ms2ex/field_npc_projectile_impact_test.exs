defmodule Ms2ex.FieldNpcProjectileImpactTest do
  # the impact application runs inside the field process on the flight
  # timer, so the tests drive the field state and the character manager
  # directly
  use Ms2ex.DataCase, async: false

  alias Ms2ex.Managers
  alias Ms2ex.Managers.Field.Npc
  alias Ms2ex.Schema
  alias Ms2ex.Types

  @character_id 918_274
  @object_id 4242
  @mob_object_id 50_000_004

  setup do
    stub_metadata(stub_data())

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

  test "a landed projectile applies its damage on the flight timer" do
    state =
      field_state(
        launch: %Types.Coord{x: 0, y: 0, z: 0},
        player_at: %Types.Coord{x: 250, y: 0, z: 0}
      )

    hit = hit(launch: %Types.Coord{x: 0, y: 0, z: 0}, travel_ms: 8)
    Npc.apply_projectile_impact(state, hit)

    {:ok, character} = Managers.Character.call(@character_id, :lookup)
    assert character.stats.health_cur < 1000
  end

  test "a projectile whiffs once its victim left the shot's reach" do
    state =
      field_state(
        launch: %Types.Coord{x: 0, y: 0, z: 0},
        player_at: %Types.Coord{x: 5_000, y: 0, z: 0}
      )

    hit = hit(launch: %Types.Coord{x: 0, y: 0, z: 0}, travel_ms: 8)
    Npc.apply_projectile_impact(state, hit)

    {:ok, character} = Managers.Character.call(@character_id, :lookup)
    assert character.stats.health_cur == 1000
  end

  test "a projectile whiffs when its victim left the field" do
    state = %{
      field_state(
        launch: %Types.Coord{x: 0, y: 0, z: 0},
        player_at: %Types.Coord{x: 250, y: 0, z: 0}
      )
      | players: %{}
    }

    hit = hit(launch: %Types.Coord{x: 0, y: 0, z: 0}, travel_ms: 8)
    Npc.apply_projectile_impact(state, hit)

    {:ok, character} = Managers.Character.call(@character_id, :lookup)
    assert character.stats.health_cur == 1000
  end

  test "the field schedules the impact when the swing releases" do
    npc = mob()

    _npc =
      Ms2ex.Managers.Field.Npc.Battle.aggro(
        npc,
        %Schema.Character{id: @character_id, object_id: @object_id},
        0
      )

    state =
      field_state(
        launch: %Types.Coord{x: 0, y: 0, z: 0},
        player_at: %Types.Coord{x: 250, y: 0, z: 0}
      )

    state = put_in(state, [:npcs, npc.object_id], npc)

    # engage, start the cast, then let the swing release past its 500ms
    # keyframe on the live clock. Mimic stubs are global, so they are
    # re-pinned right before every tick that reads storage — a concurrent
    # async test re-stubbing storage between our ticks must not swap our
    # data out from under the run
    state = tick_field(state)
    state = tick_field(state)

    Process.sleep(600)

    tick_field(state)

    # the impact delivery rides the 8ms flight timer
    assert_receive {:npc_projectile_impact, hit}, 200
    assert hit.travel_ms == 8
  end

  defp tick_field(state) do
    stub_metadata(stub_data())
    Managers.Field.Npc.tick(state)
  end

  defp stub_data do
    %{
      "skill:4001" => %{
        levels: %{
          "1" => %{
            cooldown_time: 0.0,
            motions: [
              %{
                motion_property: %{sequence_name: "Attack_01_A", sequence_speed: 1.0},
                attacks: [
                  %{
                    range: %{distance: 300.0},
                    point: "Atk01",
                    magic_path_id: 5065,
                    damage: %{rate: 1.0, value: 0}
                  }
                ]
              }
            ]
          }
        }
      },
      "animation:testmob" => %{
        sequences: %{Attack_01_A: %{id: 7, time: 1.0, keys: %{Atk01: 0.5}}}
      },
      "table:magicpath.xml" => %{
        table: %{entries: %{"5065" => [%{velocity: 30000.0, distance: 600.0}]}}
      }
    }
  end

  defp field_state(launch: launch, player_at: player_at) do
    %{
      npcs: %{},
      players: %{@character_id => @object_id},
      player_positions: %{@character_id => %{position: player_at}},
      tombstones: %{},
      npc_spawns: %{},
      topic: "projectile-impact-test",
      map_id: 0
    }
    |> then(fn state -> {state, launch} end)
    |> elem(0)
  end

  defp mob do
    metadata = %{
      basic: %{friendly: 0, class: 0, level: 10},
      stat: %{stats: %{health: 1000, physical_atk: 500}},
      model: %{name: "TestMob"},
      capsule: %{radius: 50, height: 150},
      action: %{walk_speed: 100, run_speed: 300},
      distance: %{
        sight: 500,
        sight_height_up: 300,
        sight_height_down: 100,
        last_sight_radius: 2000,
        last_sight_height_up: 400,
        last_sight_height_down: 200
      },
      skill: [%{id: 4001, level: 1}]
    }

    Types.FieldNpc.new(%{
      object_id: @mob_object_id,
      spawn_point_id: 1,
      map_id: 0,
      npc: Types.Npc.new(%{id: 22_000_000, metadata: metadata}),
      position: %Types.Coord{x: 0, y: 0, z: 0},
      rotation: %Types.Coord{x: 0, y: 0, z: 0},
      field: self(),
      spawn_radius: 0,
      next_target_scan_at: 0
    })
  end

  defp hit(launch: launch, travel_ms: travel_ms) do
    %{
      character_id: @character_id,
      caster_object_id: @mob_object_id,
      target_object_id: @object_id,
      skill_id: 4001,
      skill_level: 1,
      position: launch,
      range: 300.0,
      direction: %Types.Coord{x: 1.0, y: 0.0, z: 0.0},
      attack: 500,
      rate: 1.0,
      magic_path_id: 5065,
      arrow_overlap?: false,
      travel_ms: travel_ms,
      server_tick: 0,
      attack_counter: 1
    }
  end
end
