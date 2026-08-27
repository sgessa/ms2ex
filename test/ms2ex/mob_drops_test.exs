defmodule Ms2ex.MobDropsTest do
  use ExUnit.Case, async: false

  alias Ms2ex.Managers.Field
  alias Ms2ex.Schema
  alias Ms2ex.Storage
  alias Ms2ex.Types

  @boss_id 23_991_090
  @mob_id 23_991_091
  @hit_mob_id 23_991_093
  @corpse_mob_id 23_991_094
  @smart_mob_id 23_991_095
  @gender_mob_id 23_991_096
  @gated_mob_id 22_990_100
  @map_matching 999_001
  @map_other 999_002
  @oid 50_000_086
  @attacker %Schema.Character{id: 1, name: "Testy"}

  @item_id 200_000_001
  @item2_id 200_000_002

  @npc_metadata %{
    basic: %{friendly: 0, class: 3, level: 50},
    drop_info: %{
      global_drop_box_ids: [1],
      individual_drop_box_ids: [2],
      dead_global_drop_box_ids: [],
      global_hit_drop_box_ids: [],
      individual_hit_drop_box_ids: []
    },
    stat: %{stats: %{health: 1000, attack_speed: 100}}
  }

  @regular_metadata %{
    basic: %{friendly: 0, class: 1, level: 50},
    drop_info: %{
      global_drop_box_ids: [1],
      individual_drop_box_ids: [2],
      dead_global_drop_box_ids: [],
      global_hit_drop_box_ids: [],
      individual_hit_drop_box_ids: []
    },
    stat: %{stats: %{health: 1000, attack_speed: 100}}
  }

  @no_drop_metadata %{
    basic: %{friendly: 0, class: 3, level: 50},
    stat: %{stats: %{health: 1000, attack_speed: 100}}
  }

  @gated_metadata %{
    basic: %{friendly: 0, class: 1, level: 50},
    drop_info: %{
      global_drop_box_ids: [3],
      individual_drop_box_ids: [],
      dead_global_drop_box_ids: [],
      global_hit_drop_box_ids: [],
      individual_hit_drop_box_ids: []
    },
    stat: %{stats: %{health: 1000, attack_speed: 100}}
  }

  @hit_metadata %{
    basic: %{friendly: 0, class: 1, level: 50},
    drop_info: %{
      global_drop_box_ids: [],
      individual_drop_box_ids: [],
      dead_global_drop_box_ids: [],
      global_hit_drop_box_ids: [1],
      individual_hit_drop_box_ids: [2]
    },
    stat: %{stats: %{health: 1000, attack_speed: 100}}
  }

  @corpse_metadata %{
    basic: %{friendly: 0, class: 1, level: 50},
    corpse: %{hit_able: true},
    dead: %{time: 20},
    drop_info: %{
      global_drop_box_ids: [],
      individual_drop_box_ids: [],
      dead_global_drop_box_ids: [1],
      global_hit_drop_box_ids: [],
      individual_hit_drop_box_ids: []
    },
    stat: %{stats: %{health: 1000, attack_speed: 100}}
  }

  @smart_metadata %{
    basic: %{friendly: 0, class: 1, level: 50},
    drop_info: %{
      global_drop_box_ids: [],
      individual_drop_box_ids: [5],
      dead_global_drop_box_ids: [],
      global_hit_drop_box_ids: [],
      individual_hit_drop_box_ids: []
    },
    stat: %{stats: %{health: 1000, attack_speed: 100}}
  }

  @gender_metadata %{
    basic: %{friendly: 0, class: 1, level: 50},
    drop_info: %{
      global_drop_box_ids: [],
      individual_drop_box_ids: [6],
      dead_global_drop_box_ids: [],
      global_hit_drop_box_ids: [],
      individual_hit_drop_box_ids: []
    },
    stat: %{stats: %{health: 1000, attack_speed: 100}}
  }

  # global box 3 gates its first group on map type 7 and its item on map id
  # 999001, exercising both group- and item-level map gating
  @global_table %{
    table: %{
      drop_groups: %{
        "1" => [
          %{
            group_id: 100,
            min_level: 0,
            max_level: 0,
            drop_counts: [%{amount: 1, probability: 100}],
            owner_drop: false,
            map_type_condition: 0,
            continent_condition: 0
          }
        ],
        "3" => [
          %{
            group_id: 300,
            min_level: 0,
            max_level: 0,
            drop_counts: [%{amount: 1, probability: 100}],
            owner_drop: false,
            map_type_condition: 7,
            continent_condition: 0
          },
          %{
            group_id: 301,
            min_level: 0,
            max_level: 0,
            drop_counts: [%{amount: 1, probability: 100}],
            owner_drop: false,
            map_type_condition: 0,
            continent_condition: 0
          }
        ]
      },
      items: %{
        "100" => [
          %{
            id: @item_id,
            min_level: 0,
            max_level: 0,
            drop_count: %{min: 1, max: 1},
            rarity: 2,
            weight: 1,
            map_ids: [],
            quest_constraint: false
          }
        ],
        "300" => [
          %{
            id: @item_id,
            min_level: 0,
            max_level: 0,
            drop_count: %{min: 1, max: 1},
            rarity: 2,
            weight: 1,
            map_ids: [],
            quest_constraint: false
          }
        ],
        "301" => [
          %{
            id: @item2_id,
            min_level: 0,
            max_level: 0,
            drop_count: %{min: 1, max: 1},
            rarity: 2,
            weight: 1,
            map_ids: [@map_matching],
            quest_constraint: false
          }
        ]
      }
    }
  }

  @individual_table %{
    table: %{
      entries: %{
        "2" => %{
          "200" => %{
            group_id: 200,
            smart_drop_rate: 0,
            drop_counts: [%{count: 1, probability: 100}],
            min_level: 1,
            server_drop: false,
            smart_gender: false,
            items: [
              %{
                ids: [@item2_id, 0],
                announce: false,
                proper_job_weight: 0,
                improper_job_weight: 0,
                weight: 1,
                drop_count: %{min: 1, max: 0},
                rarities: [%{probability: 100, grade: 3}],
                enchant_level: 0,
                socket_data_id: 0,
                deduct_trade_count: false,
                deduct_repack_limit: false,
                bind: false,
                disable_break: false,
                map_ids: [],
                quest_id: 0
              }
            ]
          }
        },
        # smart drop rate + zero weight: only the job-recommended item drops
        "5" => %{
          "500" => %{
            group_id: 500,
            smart_drop_rate: 1,
            drop_counts: [%{count: 1, probability: 100}],
            min_level: 1,
            server_drop: false,
            smart_gender: false,
            items: [
              %{
                ids: [@item_id, 0],
                announce: false,
                proper_job_weight: 50,
                improper_job_weight: 1,
                weight: 0,
                drop_count: %{min: 1, max: 1},
                rarities: [%{probability: 100, grade: 2}],
                enchant_level: 0,
                socket_data_id: 0,
                deduct_trade_count: false,
                deduct_repack_limit: false,
                bind: false,
                disable_break: false,
                map_ids: [],
                quest_id: 0
              }
            ]
          }
        },
        # smart gender: only items matching the player's gender drop
        "6" => %{
          "600" => %{
            group_id: 600,
            smart_drop_rate: 0,
            drop_counts: [%{count: 1, probability: 100}],
            min_level: 1,
            server_drop: false,
            smart_gender: true,
            items: [
              %{
                ids: [@item2_id, 0],
                announce: false,
                proper_job_weight: 0,
                improper_job_weight: 0,
                weight: 1,
                drop_count: %{min: 1, max: 1},
                rarities: [%{probability: 100, grade: 2}],
                enchant_level: 0,
                socket_data_id: 0,
                deduct_trade_count: false,
                deduct_repack_limit: false,
                bind: false,
                disable_break: false,
                map_ids: [],
                quest_id: 0
              }
            ]
          }
        }
      }
    }
  }

  setup do
    :ets.insert(:metadata, {"npc:#{@boss_id}", {:ok, @npc_metadata}})
    :ets.insert(:metadata, {"npc:#{@mob_id}", {:ok, @regular_metadata}})
    :ets.insert(:metadata, {"npc:#{@mob_id + 1}", {:ok, @no_drop_metadata}})
    :ets.insert(:metadata, {"npc:#{@hit_mob_id}", {:ok, @hit_metadata}})
    :ets.insert(:metadata, {"npc:#{@corpse_mob_id}", {:ok, @corpse_metadata}})
    :ets.insert(:metadata, {"npc:#{@smart_mob_id}", {:ok, @smart_metadata}})
    :ets.insert(:metadata, {"npc:#{@gender_mob_id}", {:ok, @gender_metadata}})
    :ets.insert(:metadata, {"npc:#{@gated_mob_id}", {:ok, @gated_metadata}})
    :ets.insert(:metadata, {"table:globaldropitembox.xml", {:ok, @global_table}})
    :ets.insert(:metadata, {"table:individualdropitem.xml", {:ok, @individual_table}})

    :ets.insert(:metadata, {"map:#{@map_matching}", {:ok, %{property: %{type: 7, continent: 0}}}})
    :ets.insert(:metadata, {"map:#{@map_other}", {:ok, %{property: %{type: 1, continent: 0}}}})

    # @item_id is knight-recommended; @item2_id is male-only
    :ets.insert(
      :metadata,
      {"item:#{@item_id}",
       {:ok,
        %{
          limit: %{level: 1, gender: 2, job_recommends: [10]},
          slot_names: [],
          option: %{constant_id: 1}
        }}}
    )

    :ets.insert(
      :metadata,
      {"item:#{@item2_id}",
       {:ok,
        %{
          limit: %{level: 1, gender: 0, job_recommends: []},
          slot_names: [],
          option: %{constant_id: 1}
        }}}
    )

    :ok
  end

  defp field_npc(npc_id) do
    npc = Types.Npc.new(%{id: npc_id, metadata: Storage.Npcs.get_meta(npc_id)})

    Types.FieldNpc.new(%{
      object_id: @oid,
      spawn_point_id: nil,
      npc: npc,
      position: %Types.Coord{x: 0, y: 0, z: 0},
      rotation: %Types.Coord{x: 0, y: 0, z: 0},
      field: self()
    })
  end

  defp state_with(field_npc, map_id \\ nil),
    do: %{npcs: %{@oid => field_npc}, players: %{}, topic: "test-topic", map_id: map_id}

  defp kill(state, dmg) do
    {:reply, {:ok, mob}, new_state} =
      Field.handle_call({:inflict_dmg, @attacker, %{dmg: dmg}, @oid}, nil, state)

    {mob, new_state}
  end

  defp kill_with(state, dmg, attacker) do
    {:reply, {:ok, mob}, new_state} =
      Field.handle_call({:inflict_dmg, attacker, %{dmg: dmg}, @oid}, nil, state)

    {mob, new_state}
  end

  test "boss death drops unlocked global loot and per-dealer individual loot" do
    field_npc = field_npc(@boss_id)
    {_mob, _state} = kill(state_with(field_npc), 10_000)

    assert_received {:"$gen_cast",
                     {:add_mob_drop, _mob, %Schema.Item{item_id: @item_id, rarity: 2, amount: 1},
                      nil}}

    assert_received {:"$gen_cast",
                     {:add_mob_drop, _mob, %Schema.Item{item_id: @item2_id, rarity: 3, amount: 1},
                      %Schema.Character{id: 1}}}
  end

  test "regular mob death locks global and individual loot to the tagger" do
    field_npc = field_npc(@mob_id)
    {_mob, _state} = kill(state_with(field_npc), 10_000)

    assert_received {:"$gen_cast",
                     {:add_mob_drop, _mob, %Schema.Item{item_id: @item_id, rarity: 2, amount: 1},
                      %Schema.Character{id: 1}}}

    assert_received {:"$gen_cast",
                     {:add_mob_drop, _mob, %Schema.Item{item_id: @item2_id, rarity: 3, amount: 1},
                      %Schema.Character{id: 1}}}
  end

  test "mob without drop_info metadata drops nothing" do
    field_npc = field_npc(@mob_id + 1)
    {_mob, _state} = kill(state_with(field_npc), 10_000)

    refute_received {:"$gen_cast", {:add_mob_drop, _mob, _item, _receiver}}
  end

  test "matching map type and map id allow the drop" do
    field_npc = field_npc(@gated_mob_id)
    {_mob, _state} = kill(state_with(field_npc, @map_matching), 10_000)

    assert_received {:"$gen_cast",
                     {:add_mob_drop, _mob, %Schema.Item{item_id: @item_id}, _receiver}}

    assert_received {:"$gen_cast",
                     {:add_mob_drop, _mob, %Schema.Item{item_id: @item2_id}, _receiver}}
  end

  test "mismatched map type or map id suppress the drop" do
    field_npc = field_npc(@gated_mob_id)
    {_mob, _state} = kill(state_with(field_npc, @map_other), 10_000)

    refute_received {:"$gen_cast", {:add_mob_drop, _mob, _item, _receiver}}
  end

  test "non-lethal hits drop global and individual hit-loot boxes" do
    field_npc = field_npc(@hit_mob_id)
    {_mob, _state} = kill(state_with(field_npc), 100)

    assert_received {:"$gen_cast", {:add_mob_drop, _mob, %Schema.Item{item_id: @item_id}, nil}}

    assert_received {:"$gen_cast",
                     {:add_mob_drop, _mob, %Schema.Item{item_id: @item2_id},
                      %Schema.Character{id: 1}}}
  end

  test "lethal hit also rolls hit loot before death loot" do
    field_npc = field_npc(@hit_mob_id)
    {_mob, _state} = kill(state_with(field_npc), 10_000)

    assert_received {:"$gen_cast", {:add_mob_drop, _mob, %Schema.Item{item_id: @item_id}, nil}}
  end

  test "corpse strikes drop dead-global loot locked to the striker" do
    field_npc = field_npc(@corpse_mob_id)
    {_mob, state} = kill(state_with(field_npc), 10_000)

    refute_received {:"$gen_cast", {:add_mob_drop, _mob, _item, _receiver}}

    {:reply, {:ok, _mob2}, _state2} =
      Field.handle_call({:inflict_dmg, @attacker, %{dmg: 100}, @oid}, nil, state)

    assert_received {:"$gen_cast",
                     {:add_mob_drop, _mob2, %Schema.Item{item_id: @item_id},
                      %Schema.Character{id: 1}}}
  end

  test "smart-drop boxes only drop the job-recommended item" do
    field_npc = field_npc(@smart_mob_id)
    knight = %Schema.Character{id: 1, name: "Testy", job: :knight, gender: :male}
    {_mob, _state} = kill_with(state_with(field_npc), 10_000, knight)

    assert_received {:"$gen_cast",
                     {:add_mob_drop, _mob, %Schema.Item{item_id: @item_id}, _receiver}}

    field_npc = field_npc(@smart_mob_id)
    priest = %Schema.Character{id: 1, name: "Testy", job: :priest, gender: :male}
    {_mob2, _state2} = kill_with(state_with(field_npc), 10_000, priest)

    refute_received {:"$gen_cast", {:add_mob_drop, _mob2, _item, _receiver}}
  end

  test "smart-gender boxes only drop items matching the player's gender" do
    field_npc = field_npc(@gender_mob_id)
    male = %Schema.Character{id: 1, name: "Testy", job: :knight, gender: :male}
    {_mob, _state} = kill_with(state_with(field_npc), 10_000, male)

    assert_received {:"$gen_cast",
                     {:add_mob_drop, _mob, %Schema.Item{item_id: @item2_id}, _receiver}}

    field_npc = field_npc(@gender_mob_id)
    female = %Schema.Character{id: 1, name: "Testy", job: :knight, gender: :female}
    {_mob2, _state2} = kill_with(state_with(field_npc), 10_000, female)

    refute_received {:"$gen_cast", {:add_mob_drop, _mob2, _item, _receiver}}
  end
end
