defmodule Ms2ex.FieldRegionSkillTest do
  use ExUnit.Case, async: true

  alias Ms2ex.Enums
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
