defmodule Ms2ex.MobDropsTest do
  use ExUnit.Case, async: false

  alias Ms2ex.Managers.Field
  alias Ms2ex.Schema
  alias Ms2ex.Storage
  alias Ms2ex.Types

  @boss_id 23_991_090
  @mob_id 23_991_091
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
        }
      }
    }
  }

  setup do
    :ets.insert(:metadata, {"npc:#{@boss_id}", {:ok, @npc_metadata}})
    :ets.insert(:metadata, {"npc:#{@mob_id}", {:ok, @regular_metadata}})
    :ets.insert(:metadata, {"npc:#{@mob_id + 1}", {:ok, @no_drop_metadata}})
    :ets.insert(:metadata, {"npc:#{@gated_mob_id}", {:ok, @gated_metadata}})
    :ets.insert(:metadata, {"table:globaldropitembox.xml", {:ok, @global_table}})
    :ets.insert(:metadata, {"table:individualdropitem.xml", {:ok, @individual_table}})

    :ets.insert(:metadata, {"map:#{@map_matching}", {:ok, %{property: %{type: 7, continent: 0}}}})
    :ets.insert(:metadata, {"map:#{@map_other}", {:ok, %{property: %{type: 1, continent: 0}}}})

    for item_id <- [@item_id, @item2_id] do
      :ets.insert(
        :metadata,
        {"item:#{item_id}",
         {:ok, %{limit: %{level: 1}, slot_names: [], option: %{constant_id: 1}}}}
      )
    end

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
end
