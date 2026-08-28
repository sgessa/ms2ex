defmodule Ms2ex.BuffStatusTest do
  use ExUnit.Case, async: true

  alias Ms2ex.Types

  defp character do
    %Ms2ex.Schema.Character{
      stats: %{magical_atk_max: 100, physical_atk_max: 200, health_max: 1000, health_cur: 500}
    }
  end

  defp buff(status) do
    %Types.Buff{effect: %{status: status}}
  end

  test "combines status values and rate bonuses" do
    modifiers =
      Types.Buff.stat_modifiers(
        buff(%{values: %{magical_atk: 50}, rates: %{physical_atk: 0.1}}),
        character()
      )

    assert modifiers == %{magical_atk: 50, physical_atk: 20}
  end

  test "merges value and rate for the same stat" do
    modifiers =
      Types.Buff.stat_modifiers(
        buff(%{values: %{magical_atk: 50}, rates: %{magical_atk: 0.1}}),
        character()
      )

    assert modifiers == %{magical_atk: 60}
  end

  test "skips stats the character does not have" do
    assert Types.Buff.stat_modifiers(buff(%{values: %{piercing: 10}}), character()) == %{}
  end

  test "no status yields no modifiers" do
    assert Types.Buff.stat_modifiers(buff(%{}), character()) == %{}
  end

  test "interval uses explicit interval when positive" do
    assert Types.Buff.interval_tick(buff_with(%{duration_tick: 10_000, interval_tick: 2000})) ==
             2000
  end

  test "interval defaults to duration plus one second" do
    assert Types.Buff.interval_tick(buff_with(%{duration_tick: 3000, interval_tick: 0})) == 4000
  end

  test "ticks when the effect has recovery or dot" do
    assert Types.Buff.ticks?(buff_with_recovery())
    assert Types.Buff.ticks?(buff_with_dot())
    refute Types.Buff.ticks?(buff(%{}))
  end

  test "ticks when the effect has tick skills" do
    buff = %Types.Buff{effect: %{tick_skills: [%{id: 10_300_263, level: 2}]}}
    assert Types.Buff.ticks?(buff)
    assert Types.Buff.tick_skills(buff) == [%{id: 10_300_263, level: 2}]
  end

  test "skills and tick_skills default to empty" do
    assert Types.Buff.skills(buff(%{})) == []
    assert Types.Buff.tick_skills(buff(%{})) == []
  end

  test "dot damage combines base and target-max-hp terms and clamps on not_kill" do
    dot = %{
      is_const_damage: true,
      hp_value: 50,
      damage_by_target_max_hp: 0.1,
      sp_value: 5,
      ep_value: 0,
      not_kill: true
    }

    buff = %Types.Buff{
      effect: %{dot: %{damage: dot}},
      owner: %Ms2ex.Schema.Character{stats: %{health_max: 1000, health_cur: 1000}}
    }

    assert Types.Buff.dot_amounts(buff) == {150, 5, 0}
  end

  test "not_kill caps dot damage below current health" do
    dot = %{
      is_const_damage: true,
      hp_value: 500,
      damage_by_target_max_hp: 0.0,
      sp_value: 0,
      ep_value: 0,
      not_kill: true
    }

    buff = %Types.Buff{
      effect: %{dot: %{damage: dot}},
      owner: %Ms2ex.Schema.Character{stats: %{health_max: 1000, health_cur: 10}}
    }

    assert Types.Buff.dot_amounts(buff) == {9, 0, 0}
  end

  test "rate-based dot scales with the caster's attack" do
    dot = %{
      is_const_damage: false,
      rate: 1.0,
      type: 2,
      hp_value: 0,
      damage_by_target_max_hp: 0.0,
      sp_value: 0,
      ep_value: 0,
      not_kill: false
    }

    caster = %Ms2ex.Schema.Character{
      stats: %{
        physical_atk_cur: 10,
        magical_atk_cur: 10,
        min_weapon_atk_cur: 0,
        max_weapon_atk_cur: 0,
        bonus_atk_cur: 0,
        critical_damage_cur: 250,
        damage_cur: 0,
        piercing_cur: 0
      }
    }

    mob = %Ms2ex.Types.FieldNpc{
      stats: %{
        health: %{total: 1000, current: 500},
        defense: %{total: 100},
        physical_res: %{total: 50},
        magical_res: %{total: 50}
      }
    }

    buff = %Types.Buff{effect: %{dot: %{damage: dot}}, caster: caster, owner: mob}
    assert Types.Buff.dot_amounts(buff) == {3, 0, 0}
  end

  defp buff_with(property) do
    %Types.Buff{effect: %{property: property}}
  end

  defp buff_with_recovery do
    %Types.Buff{effect: %{recovery: %{hp_value: 1}, dot: %{damage: nil, buff: nil}}}
  end

  defp buff_with_dot do
    %Types.Buff{effect: %{recovery: nil, dot: %{damage: %{hp_value: 1}, buff: nil}}}
  end
end
