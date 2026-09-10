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
        on_enter: [%{name: "set_mesh", args: %{trigger_ids: "1000", visible: "1"}}],
        on_exit: [],
        conditions: [
          %{
            name: "user_detected",
            negate: false,
            args: %{box_ids: "9000"},
            next_state: "fight",
            actions: [%{name: "spawn_monster", args: %{spawn_ids: "101"}}]
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
            args: %{spawn_ids: "101"},
            next_state: "done",
            actions: [%{name: "set_portal", args: %{portal_id: "1", visible: "1", enable: "1"}}]
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
          args: %{box_ids: "9000", job_code: "10"},
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

  test "npc_detected only transitions once the matching spawn point's npc walks into the box" do
    state =
      base_state()
      |> put_in([:trigger_scripts, "tutorial", :states, "wait", :conditions], [
        %{
          name: "npc_detected",
          negate: false,
          args: %{spawn_ids: "102", box_id: "9000"},
          next_state: "fight",
          actions: []
        }
      ])
      |> put_in([:npcs, 60_000_001], npc_at(102, %{x: 0.0, y: 0.0, z: 0.0}))

    # far outside the box does not trigger
    state = tick(state)
    assert %{current: "wait"} = state.trigger_machines["tutorial"]

    # walking into the box does
    state =
      update_in(
        state,
        [:npcs, 60_000_001],
        &%{&1 | position: struct(Ms2ex.Types.Coord, @box.position)}
      )

    state = tick(state)

    assert %{next: "fight"} = state.trigger_machines["tutorial"]
  end

  test "create_item with an explicit item_id drops it at the spawn point, unowned" do
    stub_metadata(%{
      "item:30000783" => %{
        limit: %{level: 1, transfer_type: 3},
        property: %{type: 1},
        slot_names: [],
        option: %{constant_id: 0, pick_id: 0, static_id: 0, random_id: 0}
      }
    })

    state =
      base_state()
      |> put_in([:item_spawns, 200], %{
        spawn_point_id: 200,
        position: %{x: 2264.0, y: 741.0, z: 2250.0},
        individual_drop_box_id: 0,
        global_drop_box_id: 0,
        global_drop_level: 1
      })
      |> put_in([:trigger_scripts, "tutorial", :states, "wait", :on_enter], [
        %{name: "create_item", args: %{spawn_ids: "200", item_id: "30000783"}}
      ])
      |> tick()

    assert [%{item_id: 30_000_783, lock_character_id: 0, source_object_id: 0}] =
             Map.values(state.items)
  end

  test "create_item without an item_id rolls the spawn point's individual drop box" do
    stub_metadata(%{
      "item:30000783" => %{
        limit: %{level: 1, transfer_type: 3},
        property: %{type: 1},
        slot_names: [],
        option: %{constant_id: 0, pick_id: 0, static_id: 0, random_id: 0}
      },
      "table:individualdropitem.xml" => %{
        table: %{
          entries: %{
            "390000068" => %{
              "1" => %{
                items: [
                  %{
                    ids: [30_000_783, 0],
                    weight: 10_000,
                    proper_job_weight: 10_000,
                    improper_job_weight: 10_000,
                    drop_count: %{min: 1, max: 1},
                    rarities: [],
                    quest_id: 0,
                    map_ids: []
                  }
                ],
                group_id: 1,
                smart_drop_rate: 0,
                smart_gender: false,
                min_level: 0,
                drop_counts: [%{count: 1, probability: 100}]
              }
            }
          }
        }
      }
    })

    Mimic.stub(Ms2ex.Managers.Character, :call, fn _id, :lookup ->
      {:ok, %Ms2ex.Schema.Character{id: 1, level: 1}}
    end)

    state =
      base_state()
      |> Map.put(:players, %{1 => 60_100_000})
      |> put_in([:item_spawns, 200], %{
        spawn_point_id: 200,
        position: %{x: 2264.0, y: 741.0, z: 2250.0},
        individual_drop_box_id: 390_000_068,
        global_drop_box_id: 0,
        global_drop_level: 1
      })
      |> put_in([:trigger_scripts, "tutorial", :states, "wait", :on_enter], [
        %{name: "create_item", args: %{spawn_ids: "200"}}
      ])
      |> tick()

    assert [%{item_id: 30_000_783}] = Map.values(state.items)
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
          args: %{type: "SceneMovie", widget_name: "IsStop", condition: "1"},
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
          args: %{type: "SceneMovie", widget_name: "IsStop", condition: "2"},
          next_state: "fight",
          actions: []
        }
      ])
      |> tick()

    assert %{next: "fight"} = state.trigger_machines["tutorial"]
  end

  test "object_interacted fires once the interact object reaches the wanted state" do
    # the Blackstar Junkyard ride: the script arms the car (reactable) and
    # waits for it to flip back to normal once the player boards
    car = %{id: 10_001_001, uuid: "car-uuid", state: :normal}

    state =
      base_state()
      |> Map.put(:interactable, %{"car-uuid" => car})
      |> put_in([:trigger_scripts, "tutorial", :states, "wait", :conditions], [
        %{
          name: "object_interacted",
          negate: false,
          args: %{interact_ids: "10001001", state: "0"},
          next_state: "fight",
          actions: []
        }
      ])
      |> tick()

    assert %{next: "fight"} = state.trigger_machines["tutorial"]

    # while the car is still armed (reactable), the gate holds
    armed_state =
      base_state()
      |> Map.put(:interactable, %{"car-uuid" => %{car | state: :reactable}})
      |> put_in([:trigger_scripts, "tutorial", :states, "wait", :conditions], [
        %{
          name: "object_interacted",
          negate: false,
          args: %{interact_ids: "10001001", state: "0"},
          next_state: "fight",
          actions: []
        }
      ])
      |> tick()

    assert %{current: "wait"} = armed_state.trigger_machines["tutorial"]
  end

  test "negated conditions invert the match" do
    state =
      base_state()
      |> put_in([:trigger_scripts, "tutorial", :states, "wait", :conditions], [
        %{
          name: "user_detected",
          negate: true,
          args: %{box_ids: "9000"},
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
        %{name: "set_effect", args: %{trigger_ids: "5001-5003,5025", visible: "1"}}
      ])
      |> tick()

    assert %{current: "wait", next: nil} = state.trigger_machines["tutorial"]
    assert [5001, 5002, 5003, 5025] == effect_push_ids()
  end

  test "set_cinematic_ui type 9 broadcasts the opening black screen" do
    base_state()
    |> put_in([:trigger_scripts, "tutorial", :states, "wait", :on_enter], [
      %{name: "set_cinematic_ui", args: %{type: "9", script: "X"}}
    ])
    |> tick()

    assert {:push, <<0x68::little-16, 0xB, 1::little-16, 88, 0, 0>>} = receive_push()
  end

  test "select_camera activates a known camera vantage" do
    base_state()
    |> Map.put(:trigger_cameras, %{600 => %{id: 600, visible: false}})
    |> put_in([:trigger_scripts, "tutorial", :states, "wait", :on_enter], [
      %{name: "select_camera", args: %{trigger_id: "600", enable: "1"}}
    ])
    |> tick()

    assert {:push, <<0x4F::little-16, 0x3, 600::little-32, 1>>} = receive_push()
  end

  test "select_camera skips cameras the map does not ship" do
    base_state()
    |> put_in([:trigger_scripts, "tutorial", :states, "wait", :on_enter], [
      %{name: "select_camera", args: %{trigger_id: "777", enable: "1"}}
    ])
    |> tick()

    assert :nothing = receive_push()
  end

  test "set_agent toggles each agent figure by trigger id" do
    base_state()
    |> put_in([:trigger_scripts, "tutorial", :states, "wait", :on_enter], [
      %{name: "set_agent", args: %{trigger_ids: "8000,8001", visible: "0"}}
    ])
    |> tick()

    assert {:push, <<0x4F::little-16, 0x3, 8000::little-32, 0>>} = receive_push()
    assert {:push, <<0x4F::little-16, 0x3, 8001::little-32, 0>>} = receive_push()
  end

  test "remove_cinematic_talk clears the dialog bubble" do
    base_state()
    |> put_in([:trigger_scripts, "tutorial", :states, "wait", :on_enter], [
      %{name: "remove_cinematic_talk", args: %{}}
    ])
    |> tick()

    assert {:push, <<0x68::little-16, 0x7>>} = receive_push()
  end

  test "set_pc_emotion_loop broadcasts the player emote loop" do
    base_state()
    |> put_in([:trigger_scripts, "tutorial", :states, "wait", :on_enter], [
      %{name: "set_pc_emotion_loop", args: %{sequence_name: "Talk_A", duration: "8000"}}
    ])
    |> tick()

    assert {:push,
            <<0x4F::little-16, 0x8, 0x8, 0, 64, 31, 0, 0, 6, 0, 84, 0, 97, 0, 108, 0, 107, 0, 95,
              0, 65, 0>>} = receive_push()
  end

  test "set_pc_emotion_sequence broadcasts the player emote sequence" do
    base_state()
    |> put_in([:trigger_scripts, "tutorial", :states, "wait", :on_enter], [
      %{name: "set_pc_emotion_sequence", args: %{sequence_names: "Bore_C, Talk_A"}}
    ])
    |> tick()

    assert {:push,
            <<0x4F::little-16, 0x8, 0x7, 2::little-32, 6::little-16, 66, 0, 111, 0, 114, 0, 101,
              0, 95, 0, 67, 0, 6::little-16, 84, 0, 97, 0, 108, 0, 107, 0, 95, 0, 65, 0>>} =
             receive_push()
  end

  test "show_caption broadcasts the scripted caption card" do
    base_state()
    |> put_in([:trigger_scripts, "tutorial", :states, "wait", :on_enter], [
      %{
        name: "show_caption",
        args: %{
          type: "NameCaption",
          title: "$52000116_QD__MAIN__8$",
          desc: "$52000116_QD__MAIN__9$",
          duration: "4000",
          align: "centerLeft",
          scale: "2.3",
          offest_rate_x: "-0.15"
        }
      }
    ])
    |> tick()

    # NameCaption zero-holds both offset rates together when one is unset
    expected =
      <<0x68::little-16, 0xA>>
      |> Kernel.<>(ustring("NameCaption"))
      |> Kernel.<>(ustring("$52000116_QD__MAIN__8$"))
      |> Kernel.<>(ustring("$52000116_QD__MAIN__9$"))
      |> Kernel.<>(ustring("centerLeft"))
      |> Kernel.<>(
        <<4000::little-32, 0.0::little-float-32, 0.0::little-float-32, 2.3::little-float-32>>
      )

    assert {:push, ^expected} = receive_push()
  end

  test "set_achievement pushes the trigger event to players in the box" do
    Mimic.stub(Ms2ex.Managers.Quest, :update_conditions, fn
      character_id, type, counter, _target_string, _target_long, code_string, _code_long ->
        send(self(), {:quest_event, character_id, type, counter, code_string})
    end)

    Mimic.stub(Ms2ex.Managers.Achievement, :update, fn
      character_id, type, _counter, _ts, _tl, code_string, _cl ->
        send(self(), {:achievement_event, character_id, type, code_string})
    end)

    state =
      base_state()
      |> put_in([:trigger_boxes, 2001], %{
        id: 2001,
        position: %{x: 0.0, y: 0.0, z: 0.0},
        dimensions: %{x: 100.0, y: 100.0, z: 100.0}
      })
      |> put_player(%{x: 5.0, y: 5.0, z: 5.0}, 1)
      |> put_in([:trigger_scripts, "tutorial", :states, "wait", :on_enter], [
        %{name: "set_achievement", args: %{trigger_id: "2001", type: "trigger", achieve: "jordy"}}
      ])
      |> tick()

    assert %{current: "wait"} = state.trigger_machines["tutorial"]
    assert_received {:achievement_event, 1, :trigger, "jordy"}
    assert_received {:quest_event, 1, :trigger, 1, "jordy"}
  end

  test "set_achievement without a box reaches every player" do
    Mimic.stub(Ms2ex.Managers.Quest, :update_conditions, fn
      character_id, type, counter, _target_string, _target_long, code_string, _code_long ->
        send(self(), {:quest_event, character_id, type, counter, code_string})
    end)

    Mimic.stub(Ms2ex.Managers.Achievement, :update, fn _character_id,
                                                       _type,
                                                       _c,
                                                       _ts,
                                                       _tl,
                                                       _cs,
                                                       _cl ->
      :ok
    end)

    base_state()
    |> put_player(%{x: 5.0, y: 5.0, z: 5.0}, 1)
    |> put_player(%{x: -900.0, y: -900.0, z: 5.0}, 2)
    |> put_in([:trigger_scripts, "tutorial", :states, "wait", :on_enter], [
      # the raw action carries no box argument at all — the event is global
      %{name: "set_achievement", args: %{type: "trigger", achieve: "jordysave"}}
    ])
    |> tick()

    assert_received {:quest_event, 1, :trigger, 1, "jordysave"}
    assert_received {:quest_event, 2, :trigger, 1, "jordysave"}
  end

  test "destroy_monster frees the spawn point so it can respawn" do
    stub_metadata(%{
      "npc:11003187" => %{
        basic: %{friendly: 1, class: 0, level: 1},
        stat: %{stats: %{health: 10}}
      }
    })

    friendly_spawn = fn point ->
      %{
        spawn_point_id: point,
        npc_list: [%{npc_id: 11_003_187, count: 1}],
        on_field_create: false,
        regen_check_time: 0,
        spawned_npcs: [],
        spawned_mobs: []
      }
    end

    state =
      base_state()
      |> Map.put(:npc_spawns, %{101 => friendly_spawn.(101), 104 => friendly_spawn.(104)})
      |> put_in([:trigger_scripts, "tutorial", :states, "wait", :on_enter], [
        %{name: "spawn_monster", args: %{spawn_ids: "101"}},
        %{name: "destroy_monster", args: %{spawn_ids: "101"}},
        %{name: "spawn_monster", args: %{spawn_ids: "101"}}
      ])
      |> tick()

    # joddy was destroyed once and the respawn filled his slot again with a
    # fresh object; the untouched point 104 spawn is unaffected. the destroyed
    # object's removal is an async field message the test never drains, so it
    # still lingers in state.npcs
    assert [new_id] = state.npc_spawns[101].spawned_npcs
    assert Map.has_key?(state.npcs, new_id)
    assert map_size(state.npcs) == 2
    assert state.npc_spawns[104].spawned_npcs == []
  end

  test "set_user_value stores the value and user_value reads it" do
    state =
      base_state()
      |> put_in([:trigger_scripts, "tutorial", :states, "wait", :conditions], [
        %{
          name: "user_value",
          negate: false,
          args: %{key: "chase", value: "2"},
          next_state: "done",
          actions: []
        }
      ])
      |> enter_state("wait", entered_at: now_ms())
      |> Map.put(:user_values, %{"chase" => 2})
      |> tick()

    assert %{next: "done"} = state.trigger_machines["tutorial"]
  end

  test "set_breakable broadcasts the hide state" do
    state =
      base_state()
      |> Map.put(:breakables, %{
        2001 => %{breakable_id: 2001, uuid: "abc", visible: true, state: 2}
      })
      |> put_in([:trigger_scripts, "tutorial", :states, "wait", :on_enter], [
        %{name: "set_breakable", args: %{trigger_ids: "2001", enable: "0"}}
      ])
      |> tick()

    assert %{state: 4, visible: true} = state.breakables[2001]

    assert {:push,
            <<0x50::little-16, 0, 1::little-32, 3::little-16, "abc"::binary, 4, 1, 0::little-32,
              0::little-32>>} =
             receive_push()
  end

  test "set_dialogue balloons the spawn-point npc with the script text" do
    state =
      base_state()
      |> Map.put(:npcs, %{700 => story_npc(108, 11_003_401)})
      |> put_in([:trigger_scripts, "tutorial", :states, "wait", :on_enter], [
        %{
          name: "set_dialogue",
          args: %{type: "1", spawn_id: "108", script: "$52000116_QD__MAIN__4$", time: "2"}
        }
      ])
      |> tick()

    assert %{current: "wait"} = state.trigger_machines["tutorial"]

    expected =
      <<0x68::little-16, 0x8, 0, 700::little-32>>
      |> Kernel.<>(ustring("$52000116_QD__MAIN__4$"))
      |> Kernel.<>(<<2000::little-32, 0::little-32>>)

    assert {:push, ^expected} = receive_push()
  end

  test "set_dialogue balloons the player when the spawn point is zero" do
    _state =
      base_state()
      |> Map.put(:players, %{1 => 777})
      |> put_in([:trigger_scripts, "tutorial", :states, "wait", :on_enter], [
        %{name: "set_dialogue", args: %{type: "1", spawn_id: "0", script: "$hi$", time: "3"}}
      ])
      |> tick()

    expected =
      <<0x68::little-16, 0x8, 0, 777::little-32>>
      |> Kernel.<>(ustring("$hi$"))
      |> Kernel.<>(<<3000::little-32, 0::little-32>>)

    assert {:push, ^expected} = receive_push()
  end

  test "add_balloon_talk queues an npc balloon after the delay" do
    _state =
      base_state()
      |> Map.put(:npcs, %{700 => story_npc(108, 11_003_401)})
      |> put_in([:trigger_scripts, "tutorial", :states, "wait", :on_enter], [
        %{
          name: "add_balloon_talk",
          args: %{
            msg: "$52000135_QD__MAIN__12$",
            duration: "2000",
            spawn_id: "108",
            delay_tick: "100"
          }
        }
      ])
      |> tick()

    expected =
      <<0x68::little-16, 0x8, 0, 700::little-32>>
      |> Kernel.<>(ustring("$52000135_QD__MAIN__12$"))
      |> Kernel.<>(<<2000::little-32, 100::little-32>>)

    assert {:push, ^expected} = receive_push()
  end

  test "play_system_sound_in_box broadcasts the sound field-wide without boxes" do
    base_state()
    |> put_in([:trigger_scripts, "tutorial", :states, "wait", :on_enter], [
      %{name: "play_system_sound_in_box", args: %{sound: "System_Space_PopUp_01"}}
    ])
    |> tick()

    expected = <<0xC5::little-16>> <> ustring("System_Space_PopUp_01")
    assert {:push, ^expected} = receive_push()
  end

  test "set_sound toggles a trigger sound object" do
    state =
      base_state()
      |> Map.put(:trigger_sounds, %{3001 => %{id: 3001, visible: false}})
      |> put_in([:trigger_scripts, "tutorial", :states, "wait", :on_enter], [
        %{name: "set_sound", args: %{trigger_id: "3001", enable: "1"}}
      ])
      |> tick()

    assert {:push, <<0x4F::little-16, 3, 3001::little-32, 1>>} = receive_push()
    assert %{visible: true} = state.trigger_sounds[3001]
  end

  test "set_skill enables a trigger skill zone and removes it on disable" do
    stub_metadata(%{
      "skill:70000066" => %{id: 70_000_066, levels: %{"5" => %{motions: [], skills: []}}}
    })

    script = %{
      state_names: ["wait", "disarm"],
      states: %{
        "wait" => %{
          on_enter: [%{name: "set_skill", args: %{trigger_ids: "7005", enable: "1"}}],
          on_exit: [],
          conditions: [
            %{
              name: "wait_tick",
              negate: false,
              args: %{wait_tick: "1000"},
              next_state: "disarm",
              actions: []
            }
          ],
          next_state: ""
        },
        "disarm" => %{
          on_enter: [%{name: "set_skill", args: %{trigger_ids: "7005", enable: "0"}}],
          on_exit: [],
          conditions: [],
          next_state: ""
        }
      }
    }

    state =
      base_state()
      |> Map.put(:trigger_scripts, %{"tutorial" => script})
      |> Map.put(:trigger_skills, %{
        7005 => %{
          trigger_id: 7005,
          skill_id: 70_000_066,
          skill_level: 5,
          count: 1,
          position: %{x: 2444, y: -759, z: 2700},
          rotation: %{x: 0, y: 0, z: 0}
        }
      })
      |> tick()

    assert {:push,
            <<0x4D::little-16, 0, source_id::little-signed-integer-32,
              source_id::little-signed-integer-32, _next_tick::little-32, 1,
              2444.0::little-float-size(32), -759.0::little-float-size(32),
              2700.0::little-float-size(32), 70_000_066::little-32, 5::little-16, _rest::binary>>} =
             receive_push()

    assert state.trigger_skills[7005].source_id == source_id

    # the disarm transition queues on wait_tick, then lands next cycle
    state =
      put_in(state, [:trigger_machines, "tutorial", :entered_at], now_ms() - 1_500)
      |> tick()
      |> tick()

    assert {:push, <<0x4D::little-16, 1, removed_id::little-signed-integer-32>>} = receive_push()
    assert removed_id == source_id
    refute Map.has_key?(state.trigger_skills[7005], :source_id)
  end

  test "move_npc attaches the patrol to the matching story npc" do
    # the model animates Run_A but not Walk_A, so the waypoint's Walk_A
    # approach falls back to the model's run sequence
    stub_metadata(%{
      "animation:11003401_m_storynpc" => %{
        model: "11003401_m_storynpc",
        sequences: %{Run_A: 11, Idle_A: 3}
      }
    })

    state =
      base_state()
      |> Map.put(:patrols, %{
        "MS2PatrolData_2003" => %{
          way_points: [%{position: %{x: 100.0, y: 100.0, z: 0.0}, approach_animation: "Walk_A"}]
        }
      })
      |> Map.put(:npcs, %{
        700 => story_npc(108, 11_003_401),
        701 => %{spawn_point_id: 109, animation: 255, patrol: nil, npc: %{id: 11_003_399}}
      })
      |> put_in([:trigger_scripts, "tutorial", :states, "wait", :on_enter], [
        %{name: "move_npc", args: %{spawn_id: "108", patrol_name: "MS2PatrolData_2003"}}
      ])
      |> tick()

    npc = state.npcs[700]

    assert %{patrol: %{waypoints: [waypoint], animations: [11], speed: speed}} = npc
    assert waypoint == %{x: 100.0, y: 100.0, z: 0.0}
    assert npc.animation == 11
    assert speed == 150
    # the other npc is untouched
    assert state.npcs[701][:patrol] == nil
  end

  test "move_npc leaves npcs without a locomotion sequence in place" do
    stub_metadata(%{
      "animation:11003401_m_storynpc" => %{
        model: "11003401_m_storynpc",
        sequences: %{Idle_A: 3}
      }
    })

    {state, _log} =
      ExUnit.CaptureLog.with_log(fn ->
        base_state()
        |> Map.put(:patrols, %{
          "MS2PatrolData_2003" => %{
            way_points: [%{position: %{x: 100.0, y: 100.0, z: 0.0}, approach_animation: "Walk_A"}]
          }
        })
        |> Map.put(:npcs, %{700 => story_npc(108, 11_003_401)})
        |> put_in([:trigger_scripts, "tutorial", :states, "wait", :on_enter], [
          %{name: "move_npc", args: %{spawn_id: "108", patrol_name: "MS2PatrolData_2003"}}
        ])
        |> tick()
      end)

    # no walk/run sequence on the model: the npc stays put instead of
    # sliding across the field in its idle pose (the tick logs the missing
    # walk animation warning — expected here)
    assert %{patrol: nil, animation: 255} = state.npcs[700]
  end

  test "set_cinematic_ui frames the cutscene with a letterbox transition" do
    base_state()
    |> put_in([:trigger_scripts, "tutorial", :states, "wait", :on_enter], [
      %{name: "set_cinematic_ui", args: %{type: "3"}}
    ])
    |> tick()

    assert {:push, <<0x68::little-16, 0x3, 3::little-32, 0::little-16, 0::little-16>>} =
             receive_push()
  end

  test "set_time_scale broadcasts the field tick-rate change" do
    base_state()
    |> put_in([:trigger_scripts, "tutorial", :states, "wait", :on_enter], [
      %{
        name: "set_time_scale",
        args: %{
          enable: "1",
          start_scale: "0.5",
          end_scale: "0.5",
          duration: "10.0",
          interpolator: "1"
        }
      }
    ])
    |> tick()

    assert {:push,
            <<0xF5::little-16, 1, 0.5::little-float-32, 0.5::little-float-32,
              10.0::little-float-32, 1>>} = receive_push()
  end

  test "set_event_ui_script with box id 0 reaches every player exactly once" do
    test_pid = self()

    Mimic.stub(Ms2ex.Managers.Character, :call, fn
      _id, :lookup -> {:ok, %Ms2ex.Schema.Character{id: 1}}
      _id, _message -> :ok
    end)

    Mimic.stub(Ms2ex.Net.SenderSession, :push, fn _character, packet ->
      send(test_pid, {:banner_push, packet})
      :ok
    end)

    base_state()
    |> Map.put(:player_positions, %{
      1 => %{position: @box.position},
      2 => %{position: %{x: 0.0, y: 0.0, z: 0.0}}
    })
    |> put_in([:trigger_scripts, "tutorial", :states, "wait", :on_enter], [
      %{
        name: "set_event_ui_script",
        args: %{type: "5", script: "$X__0$", duration: "3000", box_ids: "0"}
      }
    ])
    |> tick()

    # kind 5 is the game-over style banner in the client's banner table
    assert_receive {:banner_push,
                    <<0x62::little-16, 2, 1, script_len::little-16,
                      script::binary-size(script_len)-unit(16), 3000::little-32>>},
                   1000

    assert :unicode.characters_to_binary(script, {:utf16, :little}) == "$X__0$"

    # one push per player, both covered
    assert_receive {:banner_push, _}, 1000
    refute_receive {:banner_push, _}, 100
  end

  test "move_user to a destination without the named portal uses its default spawn" do
    stub_metadata(%{
      "map:52000115" => %{
        portals: [],
        pc_spawns: [
          %{
            enable: true,
            visible: true,
            position: %{x: 5091, y: -1209, z: 1500},
            rotation: %{x: 0, y: 0, z: 180}
          }
        ]
      }
    })

    Mimic.stub(Ms2ex.Managers.Character, :call, fn
      _id, :lookup ->
        {:ok, %Ms2ex.Schema.Character{id: 1}}

      _id, {:update, character} ->
        send(self(), {:character_update, character})
        :ok

      _id, _message ->
        :ok
    end)

    Mimic.stub(Ms2ex.Managers.Field.Character, :remove_character, fn character, state ->
      %{state | players: Map.delete(state.players, character.id)}
    end)

    Mimic.stub(Ms2ex.Context.Characters, :maybe_discover_map, fn character, _map_id ->
      character
    end)

    Mimic.stub(Ms2ex.Net.SenderSession, :push, fn _character, _packet -> :ok end)

    state =
      base_state()
      |> Map.put(:map_id, 52_000_104)
      |> Map.put(:players, %{1 => 60_100_000})
      |> put_in([:trigger_scripts, "tutorial", :states, "wait", :on_enter], [
        %{name: "move_user", args: %{map_id: "52000115", portal_id: "1"}}
      ])
      |> tick()

    # the field no longer holds the player and the machine stopped itself
    assert state.players == %{}
    assert_receive({:character_update, %{change_map: change_map}}, 1000)
    assert change_map.id == 52_000_115
    # the default field spawn, lifted by the standard spawn height
    assert change_map.position == %Ms2ex.Types.Coord{x: 5091, y: -1209, z: 1525}
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
      item_spawns: %{},
      items: %{},
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

  defp story_npc(spawn_point_id, npc_id) do
    %Ms2ex.Types.FieldNpc{
      spawn_point_id: spawn_point_id,
      animation: 255,
      patrol: nil,
      velocity: {0, 0, 0},
      rotation: %{x: 0.0, y: 0.0, z: 0.0},
      send_control?: true,
      npc: %{id: npc_id, metadata: %{model: %{name: "11003401_m_storynpc"}}}
    }
  end

  defp npc_at(spawn_point_id, position) do
    %Ms2ex.Types.FieldNpc{
      object_id: 60_000_000 + spawn_point_id,
      spawn_point_id: spawn_point_id,
      position: struct(Ms2ex.Types.Coord, position),
      rotation: %Ms2ex.Types.Coord{},
      npc: %Ms2ex.Types.Npc{id: 0, metadata: %{}},
      type: :npc
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

  defp ustring(text) do
    # the length field counts characters, the payload is utf16-le
    <<String.length(text)::little-16,
      :unicode.characters_to_binary(text, :utf8, {:utf16, :little})::binary>>
  end
end
