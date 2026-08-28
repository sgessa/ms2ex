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
end
