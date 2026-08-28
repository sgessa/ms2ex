defmodule Ms2ex.BuffRecoveryTest do
  use ExUnit.Case, async: false

  alias Ms2ex.Types

  setup do
    :ets.insert(
      :metadata,
      {"additional-effect:20000027_1",
       {:ok,
        %{
          property: %{max_count: 1, duration_tick: 1000, interval_tick: 0},
          reset_condition: 0,
          persist_end_tick: 0,
          shield: nil,
          status: %{values: %{}, rates: %{}},
          recovery: %{
            recovery_rate: 10.0,
            hp_value: 100,
            hp_rate: 0.2,
            sp_value: 50,
            sp_rate: 0.1,
            ep_value: 0,
            ep_rate: 0.0,
            disable_crit: false
          }
        }}}
    )

    :ets.insert(
      :metadata,
      {"additional-effect:20000028_1",
       {:ok,
        %{
          property: %{max_count: 1, duration_tick: 1000, interval_tick: 0},
          reset_condition: 0,
          persist_end_tick: 0,
          shield: nil,
          status: %{values: %{}, rates: %{}},
          recovery: nil
        }}}
    )

    :ok
  end

  defp character do
    %Ms2ex.Schema.Character{
      id: 1,
      name: "t",
      object_id: 7,
      stats: %{
        health_max: 1000,
        health_cur: 300,
        spirit_max: 500,
        spirit_cur: 100,
        stamina_max: 500,
        stamina_cur: 100,
        magical_atk_cur: 10
      },
      sender_session_pid: nil,
      field_pid: nil,
      party_id: nil
    }
  end

  defp skill_cast do
    %Types.SkillCast{id: 0, skill_id: 20_000_027, skill_level: 1, caster: character()}
  end

  defp buff(effect_id, level) do
    Types.Buff.new(1, skill_cast(), %{id: effect_id, level: level}, character(), character())
  end

  test "buff without a shield has no shield health" do
    assert buff(20_000_027, 1).shield_health == 0
  end

  test "recovery amounts follow the reference formula" do
    assert Types.Buff.recovery_amounts(buff(20_000_027, 1), character(), false) == {400, 100, 0}
  end

  test "critical recovery multiplies the rate-based amounts" do
    assert Types.Buff.recovery_amounts(buff(20_000_027, 1), character(), true) == {450, 125, 0}
  end

  test "effects without recovery restore nothing" do
    assert Types.Buff.recovery_amounts(buff(20_000_028, 1), character(), false) == {0, 0, 0}
  end
end
