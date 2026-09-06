defmodule Ms2ex.TriggerRuntimeTest do
  use Ms2ex.DataCase, async: true

  alias Ms2ex.Managers.Field
  alias Ms2ex.Managers.Field.Npc
  alias Ms2ex.Managers.Field.Trigger

  # a script shaped like the classic tutorial: enter on user detection in a
  # box, release on the guard's death, finish after a delay
  @script %{
    state_names: ["wait", "fight", "done"],
    states: %{
      "wait" => %{
        on_enter: [%{name: "set_mesh", args: %{arg1: "1000", arg2: "1"}}],
        on_exit: [],
        conditions: [
          %{
            name: "user_detected",
            negate: false,
            args: %{arg1: "9000"},
            next_state: "fight",
            actions: [%{name: "spawn_monster", args: %{arg1: "101"}}]
          }
        ],
        next_state: ""
      },
      "fight" => %{
        on_enter: [%{name: "guide_event", args: %{event_id: "260"}}],
        on_exit: [],
        conditions: [
          %{
            name: "monster_dead",
            negate: false,
            args: %{arg1: "101"},
            next_state: "done",
            actions: [%{name: "set_portal", args: %{arg1: "1", arg2: "1", arg3: "1"}}]
          }
        ],
        next_state: ""
      },
      "done" => %{on_enter: [], on_exit: [], conditions: [], next_state: ""}
    }
  }

  @mesh %{id: 1000, visible: true, minimap_invisible: true, scale: 1.0}
  @box %{
    id: 9000,
    position: %{x: 2700.0, y: -750.0, z: 1200.0},
    dimensions: %{x: 200.0, y: 200.0, z: 300.0}
  }
  @guard_id 29_000_128

  @guard_meta %{
    basic: %{friendly: 0, class: 0, level: 1},
    stat: %{stats: %{health: 5}}
  }

  setup do
    stub_metadata(%{"npc:#{@guard_id}" => @guard_meta})
    Phoenix.PubSub.subscribe(Ms2ex.PubSub, "trigger-runtime-topic")
    :ok
  end

  test "the machine enters the first state and runs its on-enter actions" do
    state = tick(base_state())

    assert %{current: "wait", next: nil} = state.trigger_machines["tutorial"]
    assert {:push, <<0x4F::little-16, 0x3, 1000::little-32, 1, 1>> <> _} = receive_push()
  end

  test "user_detected in a trigger box spawns the guard and transitions" do
    state = tick(base_state())

    # a player far outside the box does not trigger
    state = put_player(state, %{x: 0.0, y: 0.0, z: 0.0}, 1)
    state = tick(state)
    assert %{current: "wait"} = state.trigger_machines["tutorial"]

    # stepping into the box does
    state = put_player(state, %{x: 2710.0, y: -760.0, z: 1210.0}, 1)
    state = tick(state)

    assert %{next: "fight"} = state.trigger_machines["tutorial"]

    state = tick(state)
    assert %{current: "fight"} = state.trigger_machines["tutorial"]
    assert spawn_count(state, 101) == 1
    # the fight state's on-enter fired the guide event
    assert guide_event_push?(260)
  end

  test "user_detected can gate on the job code" do
    state =
      base_state()
      |> Trigger.track_job(1, 10)
      |> put_in([:trigger_scripts, "tutorial", :states, "wait", :conditions], [
        %{
          name: "user_detected",
          negate: false,
          args: %{arg1: "9000", arg2: "10"},
          next_state: "fight",
          actions: []
        }
      ])

    # a player of a different job standing in the box does not trigger
    state = Trigger.track_job(state, 1, 100)
    state = put_player(state, %{x: 2710.0, y: -760.0, z: 1210.0}, 1)
    state = tick(state)

    assert %{current: "wait"} = state.trigger_machines["tutorial"]
  end

  test "monster_dead waits for the spawn wipe then transitions" do
    state =
      base_state()
      |> load_guard()
      |> enter_state("fight")
      |> tick()

    drain_pushes()

    # the guard is alive
    assert %{current: "fight"} = state.trigger_machines["tutorial"]

    state = kill_all_mobs(state)
    state = tick(state)

    # the transition lands on the cycle after the condition fires
    assert %{next: "done"} = state.trigger_machines["tutorial"]

    state = tick(state)
    assert %{current: "done"} = state.trigger_machines["tutorial"]
    assert portal_update_push?()
  end

  test "skip_cutscene jumps to the armed state and confirms" do
    state =
      base_state()
      |> enter_state("fight")
      |> Map.put(:trigger_skips, %{"tutorial" => "done"})

    state = Trigger.skip_cutscene(state)

    assert %{next: "done"} = state.trigger_machines["tutorial"]
    assert {:push, <<0x68::little-16, 0x5>>} = receive_push()
  end

  test "skip_cutscene stops a playing movie when no skip is armed" do
    state =
      base_state()
      |> put_in([:widgets, :scene_movie], %{conditions: %{}, movie_id: 1})
      |> put_in([:trigger_scripts, "tutorial", :states, "wait", :conditions], [
        %{
          name: "widget_condition",
          negate: false,
          args: %{arg1: "SceneMovie", arg2: "IsStop", arg3: "1"},
          next_state: "fight",
          actions: []
        }
      ])

    state = Trigger.skip_cutscene(state)
    state = tick(state)

    assert %{next: "fight"} = state.trigger_machines["tutorial"]
  end

  test "wait_tick does not transition before the delay elapses" do
    state =
      base_state()
      |> put_in([:trigger_scripts, "tutorial", :states, "fight", :conditions], [
        %{
          name: "wait_tick",
          negate: false,
          args: %{wait_tick: "5000"},
          next_state: "done",
          actions: []
        }
      ])
      |> enter_state("fight", entered_at: now_ms())
      |> tick()

    assert %{current: "fight"} = state.trigger_machines["tutorial"]
  end

  test "wait_tick transitions once the named delay has elapsed" do
    state =
      base_state()
      |> put_in([:trigger_scripts, "tutorial", :states, "fight", :conditions], [
        %{
          name: "wait_tick",
          negate: false,
          args: %{wait_tick: "1000"},
          next_state: "done",
          actions: []
        }
      ])
      |> enter_state("fight", entered_at: now_ms() - 1_500)
      |> tick()

    # the transition is queued and lands on the next machine cycle
    assert %{next: "done"} = state.trigger_machines["tutorial"]
  end

  test "update_widget records client state for widget_condition" do
    state =
      base_state()
      |> put_in([:widgets, :scene_movie], %{conditions: %{}})
      |> Trigger.update_widget(:scene_movie, 2)
      |> put_in([:trigger_scripts, "tutorial", :states, "wait", :conditions], [
        %{
          name: "widget_condition",
          negate: false,
          args: %{arg1: "SceneMovie", arg2: "IsStop", arg3: "2"},
          next_state: "fight",
          actions: []
        }
      ])
      |> tick()

    assert %{next: "fight"} = state.trigger_machines["tutorial"]
  end

  test "negated conditions invert the match" do
    state =
      base_state()
      |> put_in([:trigger_scripts, "tutorial", :states, "wait", :conditions], [
        %{
          name: "user_detected",
          negate: true,
          args: %{arg1: "9000"},
          next_state: "fight",
          actions: []
        }
      ])
      |> put_player(%{x: 2710.0, y: -760.0, z: 1210.0}, 1)
      |> tick()

    # the player IS in the box, so the negated condition does not fire
    assert %{current: "wait"} = state.trigger_machines["tutorial"]
  end

  test "guide summaries are held while the player is path-moved and released after" do
    held =
      base_state()
      |> Map.put(:path_move_active, true)
      |> put_in([:trigger_scripts, "tutorial", :states, "wait", :on_enter], [
        %{name: "show_guide_summary", args: %{entity_id: "25201421", text_id: "25201421"}}
      ])
      |> tick()

    # nothing is broadcast while the hold is on, but the hint is remembered
    assert %{pending_guide: %{entity_id: 25_201_421}} = held
    refute_receive {:push, _}

    # when the scripted move releases the player, the hint goes out
    Trigger.release_guide_hold(held)
    assert_receive {:push, <<0x4F::little-16, 8, 2, _::binary>>}
  end

  test "set_effect expands inclusive ranges into one packet per id" do
    # the knight tutorial's arrow trails toggle ranges like "5001-5025"
    state =
      base_state()
      |> put_in([:trigger_scripts, "tutorial", :states, "wait", :on_enter], [
        %{name: "set_effect", args: %{arg1: "5001-5003,5025", arg2: "1"}}
      ])
      |> tick()

    assert %{current: "wait", next: nil} = state.trigger_machines["tutorial"]
    assert [5001, 5002, 5003, 5025] == effect_push_ids()
  end

  test "set_cinematic_ui type 9 broadcasts the opening black screen" do
    base_state()
    |> put_in([:trigger_scripts, "tutorial", :states, "wait", :on_enter], [
      %{name: "set_cinematic_ui", args: %{arg1: "9", arg2: "X"}}
    ])
    |> tick()

    assert {:push, <<0x68::little-16, 0xB, 1::little-16, 88, 0, 0>>} = receive_push()
  end

  test "set_pc_emotion_loop broadcasts the player emote loop" do
    base_state()
    |> put_in([:trigger_scripts, "tutorial", :states, "wait", :on_enter], [
      %{name: "set_pc_emotion_loop", args: %{arg1: "Talk_A", arg2: "8000"}}
    ])
    |> tick()

    assert {:push,
            <<0x4F::little-16, 0x8, 0x8, 0, 64, 31, 0, 0, 6, 0, 84, 0, 97, 0, 108, 0, 107, 0, 95,
              0, 65, 0>>} = receive_push()
  end

  test "move_npc attaches the patrol to the matching story npc" do
    state =
      base_state()
      |> Map.put(:patrols, %{
        "MS2PatrolData_2003" => %{
          way_points: [%{position: %{x: 100.0, y: 100.0, z: 0.0}, approach_animation: "Run_A"}]
        }
      })
      |> Map.put(:npcs, %{
        700 => %{
          spawn_point_id: 108,
          animation: 255,
          patrol: nil,
          velocity: {0, 0, 0},
          rotation: %{x: 0.0, y: 0.0, z: 0.0},
          send_control?: true,
          npc: %{id: 11_003_401}
        },
        701 => %{spawn_point_id: 109, animation: 255, patrol: nil, npc: %{id: 11_003_399}}
      })
      |> put_in([:trigger_scripts, "tutorial", :states, "wait", :on_enter], [
        %{name: "move_npc", args: %{arg1: "108", arg2: "MS2PatrolData_2003"}}
      ])
      |> tick()

    npc = state.npcs[700]

    assert %{patrol: %{waypoints: [waypoint], speed: speed}} = npc
    assert waypoint == %{x: 100.0, y: 100.0, z: 0.0}
    assert speed == 150
    # the other npc is untouched
    assert state.npcs[701][:patrol] == nil
  end

  test "set_cinematic_ui frames the cutscene with a letterbox transition" do
    base_state()
    |> put_in([:trigger_scripts, "tutorial", :states, "wait", :on_enter], [
      %{name: "set_cinematic_ui", args: %{arg1: "3"}}
    ])
    |> tick()

    assert {:push, <<0x68::little-16, 0x3, 3::little-32, 0::little-16, 0::little-16>>} =
             receive_push()
  end

  # -- helpers ---------------------------------------------------------

  defp base_state do
    %{
      npcs: %{},
      player_positions: %{},
      players: %{},
      topic: "trigger-runtime-topic",
      map_id: nil,
      local_id_counter: 50_000_000,
      trigger_scripts: %{"tutorial" => @script},
      trigger_meshes: %{1000 => @mesh},
      trigger_boxes: %{9000 => @box},
      widgets: %{},
      portals: %{50_000_001 => portal(1)},
      # the tutorial's gated spawn point, not yet filled
      npc_spawns: %{
        50_000_002 => %{
          id: 50_000_002,
          spawn_point_id: 101,
          npc_ids: [@guard_id],
          population: 1,
          regen_check_time: 10,
          spawned_mobs: [],
          spawn_tick: :infinity,
          position: %{x: 2700.0, y: -750.0, z: 1200.0},
          rotation: nil
        }
      }
    }
    |> Trigger.init_machines()
  end

  defp portal(id) do
    %{
      id: id,
      object_id: 50_000_000 + id,
      visible: false,
      enable: false,
      minimap_visible: false,
      target_map_id: 20_000_062
    }
  end

  defp enter_state(state, state_name, opts \\ []) do
    state
    |> put_in([:trigger_machines, "tutorial", :current], state_name)
    |> put_in([:trigger_machines, "tutorial", :next], nil)
    |> put_in(
      [:trigger_machines, "tutorial", :entered_at],
      Keyword.get(opts, :entered_at, now_ms() - 6_000)
    )
  end

  defp load_guard(state) do
    doc = %{
      npc_ids: [@guard_id],
      regen_check_time: 10,
      population: 1,
      position: %{x: 0.0, y: 0.0, z: 0.0},
      rotation: %{x: 0.0, y: 0.0, z: 0.0},
      spawn_point_id: 101
    }

    state = Npc.load_spawn(state, doc, doc.npc_ids)
    {:noreply, state} = Field.handle_info(:tick_npcs, state)
    state
  end

  defp put_player(state, position, character_id) do
    Trigger.track_position(state, character_id, position)
  end

  defp kill_all_mobs(state) do
    Enum.reduce(state.npcs, state, fn
      {oid, _npc}, state ->
        {:reply, {:ok, _mob}, state} =
          Field.handle_call(
            {:inflict_dmg, %{id: 1, name: "Testy"}, %{dmg: 2000}, oid},
            nil,
            state
          )

        state
    end)
  end

  defp spawn_count(state, spid) do
    state.npc_spawns
    |> Enum.filter(fn {_id, spawn} -> spawn[:spawn_point_id] == spid end)
    |> Enum.map(fn {_id, spawn} -> length(spawn.spawned_mobs) end)
    |> Enum.sum()
  end

  defp tick(state) do
    # tests tick back-to-back; drop the rate limit so every call runs
    state =
      Map.update(state, :trigger_machines, %{}, fn machines ->
        Map.new(machines, fn {name, machine} ->
          {name, %{machine | next_tick: now_ms() - 100_000}}
        end)
      end)

    Trigger.tick(state)
  end

  defp receive_push do
    receive do
      {:push, packet} -> {:push, packet}
    after
      100 -> :nothing
    end
  end

  defp guide_event_push?(event_id) do
    receive do
      {:push, <<0x4F::little-16, 0x8, 0x1, id::little-32>>} when id == event_id -> true
      {:push, _other} -> guide_event_push?(event_id)
    after
      100 -> false
    end
  end

  # mob deaths interleave stats/control broadcasts with trigger packets
  defp portal_update_push? do
    receive do
      {:push, <<0x49::little-16, 0x2, 1::little-32, 1, 1, _::binary>>} ->
        true

      {:push, _other} ->
        portal_update_push?()
    after
      100 -> false
    end
  end

  defp effect_push_ids do
    receive do
      {:push, <<0x4F::little-16, 0x3, id::little-32, 1, 0, _::binary>>} ->
        [id | effect_push_ids()]

      {:push, _other} ->
        effect_push_ids()
    after
      100 -> []
    end
  end

  defp drain_pushes do
    receive do
      {:push, _packet} -> drain_pushes()
    after
      0 -> :ok
    end
  end

  defp now_ms, do: System.monotonic_time(:millisecond)
end
