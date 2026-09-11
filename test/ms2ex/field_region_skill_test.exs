defmodule Ms2ex.FieldRegionSkillTest do
  use Ms2ex.DataCase, async: true
  use Mimic

  alias Ms2ex.Enums
  alias Ms2ex.Managers
  alias Ms2ex.Managers.Field.RegionSkill
  alias Ms2ex.Schema.Character
  alias Ms2ex.Types

  @mob_id 23_991_090
  @oid 50_000_086

  @npc_metadata %{
    basic: %{friendly: 0, class: 1},
    stat: %{stats: %{health: 1000, attack_speed: 100}}
  }

  test "region splash damage updates the mob without crashing" do
    npc = Types.Npc.new(%{id: @mob_id, metadata: @npc_metadata})

    mob =
      Types.FieldNpc.new(%{
        object_id: @oid,
        spawn_point_id: nil,
        npc: npc,
        position: %Types.Coord{x: 0, y: 0, z: 0},
        rotation: %Types.Coord{x: 0, y: 0, z: 0},
        field: self()
      })

    state = %{npcs: %{@oid => mob}, players: %{}, topic: "test-topic", map_id: nil}
    skill_cast = splash_cast(mob.position)

    new_state = RegionSkill.apply_splash(skill_cast, state)

    assert new_state.npcs[@oid].stats.health.current < mob.stats.health.current
  end

  test "load_zones assigns stable source ids from the field counter" do
    stub_metadata(%{
      "map:2000083" => %{
        region_skills: [
          %{
            skill_id: 70_000_018,
            skill_level: 1,
            interval: 700,
            position: %{x: -1350.0, y: 3000.0, z: 1650.0},
            rotation: %{x: 0, y: 0, z: 0}
          }
        ]
      }
    })

    {counter, zones} = RegionSkill.load_zones(2_000_083, 50_000_000)

    assert length(zones) == 1
    zone = hd(zones)
    assert zone.source_id == 50_000_000
    assert zone.skill_id == 70_000_018
    assert zone.skill_level == 1
    assert zone.interval == 700
    assert zone.position == %{x: -1350.0, y: 3000.0, z: 1650.0}
    assert counter == 50_000_001

    # a map without zones leaves the counter untouched
    stub_metadata(%{"map:2000083" => %{region_skills: []}})
    assert {50_000_000, []} = RegionSkill.load_zones(2_000_083, 50_000_000)
  end

  test "load_cube_zones assigns stable source ids from the field counter" do
    stub_metadata(%{
      "map:2000083" => %{
        cube_skills: [
          %{
            skill_id: 70_000_008,
            skill_level: 1,
            position: %{x: 3900, y: 3600, z: 3000},
            rotation: %{x: 0, y: 0, z: 90}
          }
        ]
      },
      "skill:70000008" => %{
        levels: %{
          "1" => %{
            motions: [
              %{
                attacks: [
                  %{
                    range: %{type: 1, distance: 50, height: 70},
                    damage: %{rate: 0.0, value: 0, damage_by_target_max_hp: 0.0}
                  }
                ]
              }
            ]
          }
        }
      }
    })

    {counter, zones} = RegionSkill.load_cube_zones(2_000_083, 50_000_010)

    assert length(zones) == 1
    zone = hd(zones)
    assert zone.source_id == 50_000_010
    assert zone.skill_id == 70_000_008
    assert zone.skill_level == 1
    assert zone.range == %{type: 1, distance: 50, height: 70}
    assert zone.damage == %{rate: 0.0, value: 0, damage_by_target_max_hp: 0.0}
    assert counter == 50_000_011
  end

  test "tick_cube_zones boosts players standing inside a lane" do
    stub_metadata(%{"additional-effect:70000008_1" => speed_up_effect()})

    character = %Ms2ex.Schema.Character{
      id: 1,
      name: "Testy",
      object_id: 777,
      stats: %{movement_speed_max: 100}
    }

    stub(Managers.Character, :call, fn
      1, :lookup -> {:ok, character}
      other, :lookup -> {:error, other}
    end)

    state = %{
      topic: "cube-zone-topic",
      buffs: %{},
      players: %{1 => 777, 2 => 778},
      player_positions: %{
        1 => %{position: %{x: 3880, y: 3600, z: 3160}, job_code: nil},
        2 => %{position: %{x: 4125, y: 3675, z: 3160}, job_code: nil}
      },
      local_id_counter: 50_000_000,
      cube_skill_zones: [
        %{
          source_id: 1,
          skill_id: 70_000_008,
          skill_level: 1,
          position: %{x: 3900, y: 3600, z: 3000},
          range: %{
            type: 1,
            distance: 50,
            range_add_y: 50,
            width: 100,
            height: 70,
            apply_target: 5
          },
          skills: [%{id: 70_000_008, level: 1}]
        }
      ]
    }

    Phoenix.PubSub.subscribe(Ms2ex.PubSub, "cube-zone-topic")
    new_state = RegionSkill.tick_cube_zones(state)

    # the inside player got the Speed Up buff registered and broadcast
    assert map_size(new_state.buffs) == 1
    assert [_buff_id] = Map.values(new_state.buffs)

    assert_receive {:push,
                    <<0x48::little-16, 0, owner::little-32, _buff_object::little-32,
                      _caster::little-32, _::binary>>},
                   200

    assert owner == 777
    assert new_state.local_id_counter > 50_000_000
  end

  test "tick_cube_zones matches cylinder zones by radius" do
    stub_metadata(%{"additional-effect:70000099_1" => speed_up_effect()})

    character = %Ms2ex.Schema.Character{
      id: 1,
      name: "Testy",
      object_id: 777,
      stats: %{movement_speed_max: 100}
    }

    stub(Managers.Character, :call, fn
      1, :lookup -> {:ok, character}
      other, :lookup -> {:error, other}
    end)

    state = %{
      topic: "cube-zone-topic",
      buffs: %{},
      players: %{1 => 777},
      player_positions: %{
        # inside the circle: 140 < radius 150, z within the raised band
        1 => %{position: %{x: 3990, y: 3600, z: 3160}, job_code: nil}
      },
      local_id_counter: 50_000_000,
      cube_skill_zones: [
        %{
          source_id: 1,
          skill_id: 70_000_099,
          skill_level: 1,
          position: %{x: 3900, y: 3600, z: 3000},
          range: %{type: 2, distance: 150, height: 150, apply_target: 5},
          skills: [%{id: 70_000_099, level: 1}]
        }
      ]
    }

    Phoenix.PubSub.subscribe(Ms2ex.PubSub, "cube-zone-topic")
    new_state = RegionSkill.tick_cube_zones(state)
    assert map_size(new_state.buffs) == 1
  end

  test "tick_cube_zones deals the attack's max-health damage to players" do
    # the falling-rock zones carry no additional effect — pure attack damage
    stub_metadata(%{})

    character = %Ms2ex.Schema.Character{
      id: 1,
      name: "Testy",
      object_id: 777,
      stats: %{health_max: 5000, health_cur: 5000}
    }

    stub(Managers.Character, :call, fn
      1, :lookup -> {:ok, character}
      other, :lookup -> {:error, other}
    end)

    stub(Managers.Character, :cast, fn
      %{id: 1}, {:consume_stat, :health, dmg} -> send(self(), {:zone_damage, dmg})
      _target, _msg -> :ok
    end)

    state = %{
      topic: "cube-zone-topic",
      buffs: %{},
      players: %{1 => 777},
      player_positions: %{
        # inside the circle: 90 < radius 150, z within the raised band
        1 => %{position: %{x: 3950, y: 3600, z: 3160}, job_code: nil}
      },
      local_id_counter: 50_000_000,
      cube_skill_zones: [
        %{
          source_id: 1,
          skill_id: 70_000_099,
          skill_level: 1,
          position: %{x: 3900, y: 3600, z: 3000},
          range: %{type: 2, distance: 150, height: 150, apply_target: 5},
          skills: [%{id: 70_000_099, level: 1}],
          damage: %{
            rate: 0.0,
            value: 0,
            count: 1,
            is_const_damage: false,
            damage_by_target_max_hp: 0.1
          }
        }
      ]
    }

    Phoenix.PubSub.subscribe(Ms2ex.PubSub, "cube-zone-topic")
    new_state = RegionSkill.tick_cube_zones(state)

    # 10% of the target's max health reached the character manager
    assert_receive {:zone_damage, 500}

    # and broadcast as a tile record: [op][mode 0x6][skill uid 0][skill id]
    # [level][target count][object id][damage count][pos][dir][type][dmg]
    assert_receive {:push,
                    <<_op::16, 0x6, 0::size(64), skill_id::little-32, level::little-16, 1,
                      object_id::little-32, 1, _rest::binary>>}

    assert skill_id == 70_000_099
    assert level == 1
    assert object_id == 777

    # the rock zone carries no additional effect, so no buff applies
    assert map_size(new_state.buffs) == 0
  end

  defp speed_up_effect do
    %{
      id: 70_000_008,
      status: %{
        values: %{},
        rates: %{movement_speed: 3.0},
        special_values: %{},
        special_rates: %{}
      },
      update: %{cancel: %{check_same_caster: false, ids: [70_000_009]}, reset_cooldown: []},
      dot: %{damage: nil, buff: nil},
      level: 1,
      property: %{
        type: 1,
        category: 0,
        max_count: 1,
        duration_tick: 2000,
        interval_tick: 0,
        delay_tick: 0,
        stun: 0,
        remove_on_logout: false,
        keep_on_death: false,
        keep_condition: :timer_duration,
        event_type: :none
      },
      reset_condition: 1,
      persist_end_tick: 1,
      shield: nil,
      recovery: nil,
      skills: [],
      tick_skills: [],
      modify_overlap: []
    }
  end

  test "region splash damage ignores friendly npcs" do
    friendly_metadata = put_in(@npc_metadata, [:basic, :friendly], 1)

    mob = field_npc(@oid, Types.Npc.new(%{id: @mob_id, metadata: @npc_metadata}))
    friendly_oid = @oid + 1

    friendly =
      field_npc(friendly_oid, Types.Npc.new(%{id: 11_000_001, metadata: friendly_metadata}))

    state = %{
      npcs: %{@oid => mob, friendly_oid => friendly},
      players: %{},
      topic: "test-topic",
      map_id: nil
    }

    new_state = RegionSkill.apply_splash(splash_cast(mob.position), state)

    assert new_state.npcs[@oid].stats.health.current < mob.stats.health.current
    assert new_state.npcs[friendly_oid].stats.health.current == friendly.stats.health.current
  end

  defp field_npc(object_id, npc) do
    Types.FieldNpc.new(%{
      object_id: object_id,
      spawn_point_id: nil,
      npc: npc,
      position: %Types.Coord{x: 0, y: 0, z: 0},
      rotation: %Types.Coord{x: 0, y: 0, z: 0},
      field: self()
    })
  end

  defp splash_cast(position) do
    %Types.SkillCast{
      skill_id: 10_300_141,
      skill_level: 1,
      caster: %Character{
        id: 1,
        object_id: 99,
        stats: %{
          min_weapon_atk_cur: 100,
          max_weapon_atk_cur: 100,
          bonus_atk_cur: 0,
          physical_atk_cur: 1000,
          magical_atk_cur: 1000,
          damage_cur: 0,
          critical_damage_cur: 125,
          piercing_cur: 0
        }
      },
      motion_point: 0,
      attack_point: 0,
      position: position,
      direction: %Types.Coord{x: 0, y: 0, z: 0},
      rotation: %Types.Coord{x: 0, y: 0, z: 0},
      meta: %{
        property: %{attack_type: Enums.AttackType.get_value(:magic)},
        levels: %{
          "1" => %{
            motions: [
              %{
                attacks: [
                  %{
                    damage: %{rate: 1.0, value: 0},
                    skills: [],
                    skills_on_damage: []
                  }
                ]
              }
            ]
          }
        }
      }
    }
  end
end
