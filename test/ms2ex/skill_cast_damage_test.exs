defmodule Ms2ex.SkillCastDamageTest do
  use ExUnit.Case, async: true

  alias Ms2ex.Types.SkillCast

  # a two-projectile skill (e.g. Energy Bolt): one motion, two attacks, each
  # with its own damage record
  @multi_attack %{
    levels: %{
      "1" => %{
        motions: [
          %{
            motion_property: %{sequence_name: "IB_F"},
            attacks: [
              %{damage: %{count: 1, value: 0, rate: 0.6}},
              %{damage: %{count: 1, value: 0, rate: 0.9}}
            ]
          }
        ]
      }
    }
  }

  @single_attack %{
    levels: %{
      "1" => %{
        motions: [
          %{
            motion_property: %{sequence_name: "Swing_A"},
            attacks: [%{damage: %{count: 1, value: 12, rate: 1.83}}]
          }
        ]
      }
    }
  }

  @no_attack %{
    levels: %{
      "1" => %{motions: [%{motion_property: %{sequence_name: ""}, attacks: []}]}
    }
  }

  test "each attack point resolves its own damage record" do
    first = %SkillCast{skill_level: 1, meta: @multi_attack, attack_point: 0}
    second = %SkillCast{skill_level: 1, meta: @multi_attack, attack_point: 1}

    assert_in_delta SkillCast.damage_rate(first), 0.6, 1.0e-6
    assert_in_delta SkillCast.damage_rate(second), 0.9, 1.0e-6
  end

  test "out-of-range attack points fall back to the motion's first attack" do
    cast = %SkillCast{skill_level: 1, meta: @multi_attack, attack_point: 255}
    assert_in_delta SkillCast.damage_rate(cast), 0.6, 1.0e-6
    assert SkillCast.damage_value(cast) == 0
  end

  test "single-attack skills resolve their one damage record" do
    cast = %SkillCast{skill_level: 1, meta: @single_attack}
    assert_in_delta SkillCast.damage_rate(cast), 1.83, 1.0e-6
    assert SkillCast.damage_value(cast) == 12
  end

  test "skills without attack docs resolve to zero instead of a silent fraction" do
    cast = %SkillCast{skill_level: 1, meta: @no_attack}
    assert SkillCast.damage_rate(cast) == 0.0
    assert SkillCast.damage_value(cast) == 0
  end

  test "the second motion's attacks resolve through the motion point" do
    meta = %{
      levels: %{
        "1" => %{
          motions: [
            %{attacks: [%{damage: %{rate: 0.5, value: 0}}]},
            %{attacks: [%{damage: %{rate: 2.5, value: 7}}]}
          ]
        }
      }
    }

    cast = %SkillCast{skill_level: 1, meta: meta, motion_point: 1, attack_point: 0}
    assert_in_delta SkillCast.damage_rate(cast), 2.5, 1.0e-6
    assert SkillCast.damage_value(cast) == 7
  end

  test "on-hit effects come from the relayed attack point" do
    meta = %{
      levels: %{
        "1" => %{
          motions: [
            %{
              attacks: [
                %{skills: [%{id: 1_000_001, level: 1}], skills_on_damage: []},
                %{skills: [%{id: 1_000_002, level: 1}], skills_on_damage: []}
              ]
            }
          ]
        }
      }
    }

    first = %SkillCast{skill_level: 1, meta: meta, attack_point: 0}
    second = %SkillCast{skill_level: 1, meta: meta, attack_point: 1}

    assert Enum.map(SkillCast.attack_skills(first), & &1.id) == [1_000_001]
    assert Enum.map(SkillCast.attack_skills(second), & &1.id) == [1_000_002]
  end
end
