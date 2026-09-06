defmodule Ms2ex.NpcEmotionTest do
  use Ms2ex.DataCase, async: true

  alias Ms2ex.Managers.Field.Npc
  alias Ms2ex.Managers.Field.Trigger

  @topic "npc-emotion-test"

  setup do
    stub_metadata(%{
      "npc:11003399" => %{
        basic: %{friendly: 1, class: 0, level: 1},
        stat: %{stats: %{health: 100}},
        model: %{name: "11003300_M_MapleKnightRecruit2"}
      },
      "animation:11003300_m_mapleknightrecruit2" => %{
        model: "11003300_m_mapleknightrecruit2",
        sequences: %{
          Down_Idle_B: 0,
          Idle_A: 3,
          Emotion_lie_facedown_Idle_A: 4,
          Emotion_lie_facedown_Down_A: 5
        }
      }
    })

    Phoenix.PubSub.subscribe(Ms2ex.PubSub, @topic)
    :ok
  end

  # the punishment beat: spawn the lying lance and emote it face-down
  test "spawn + scripted emote streams the lying sequence" do
    state =
      base_state()
      |> put_in([:trigger_scripts, "beat"], %{
        state_names: ["beat"],
        states: %{
          "beat" => %{
            on_enter: [
              %{name: "spawn_monster", args: %{arg1: "109"}},
              %{
                name: "set_npc_emotion_loop",
                args: %{arg1: "109", arg2: "Emotion_lie_facedown_Idle_A", arg3: "600000"}
              }
            ],
            on_exit: [],
            conditions: [],
            next_state: ""
          }
        }
      })
      |> Trigger.init_machines()
      |> tick()

    [{object_id, npc}] = Map.to_list(state.npcs)

    # the npc carries the script's spawn point id, so the emote found it
    assert npc.spawn_point_id == 109
    assert npc.animation == 4

    assert_receive {:push,
                    <<0x59::little-16, 1::little-16, 26::little-16, ^object_id::little-32, 2,
                      _pos::6-bytes, _rot::little-signed-16, _vel::6-bytes,
                      _speed::little-signed-16, _state, 4::little-signed-16,
                      _counter::little-signed-16>>}
  end

  defp base_state do
    doc = %{
      npc_list: [%{npc_id: 11_003_399, count: 1}],
      regen_check_time: 0,
      population: 1,
      position: %{x: 150.0, y: -225.0, z: 1350.0},
      rotation: %{x: 0.0, y: 0.0, z: 180.0},
      spawn_point_id: 109,
      on_field_create: false
    }

    %{
      topic: @topic,
      npcs: %{},
      npc_spawns: %{},
      players: %{},
      map_id: nil,
      local_id_counter: 50_000_000,
      script_controlled_npcs: true,
      trigger_scripts: %{},
      trigger_machines: %{}
    }
    |> put_in([:npc_spawns, 109], Map.merge(doc, %{spawned_mobs: [], spawned_npcs: []}))
  end

  defp tick(state) do
    now = System.monotonic_time(:millisecond)

    machines =
      Map.new(state.trigger_machines, fn {name, m} -> {name, %{m | next_tick: now - 100_000}} end)

    state = Trigger.tick(%{state | trigger_machines: machines})
    Npc.tick(state)
  end
end
