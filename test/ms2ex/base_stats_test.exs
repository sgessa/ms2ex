defmodule Ms2ex.BaseStatsTest do
  use ExUnit.Case, async: true

  alias Ms2ex.Formulas.AttackStats
  alias Ms2ex.Formulas.BaseStats

  test "primary stats grow from level and job" do
    wizard = BaseStats.get(:wizard, 70)
    knight = BaseStats.get(:knight, 70)

    assert wizard.intelligence == 426
    assert wizard.strength == 17
    assert knight.strength == 371
    assert wizard.intelligence > knight.intelligence
  end

  test "derived stats use level and job" do
    stats = BaseStats.all(:wizard, 70)

    assert stats.defense == 70
    assert stats.evasion == 70
    assert stats.critical_rate == 40
    assert stats.physical_res == 11
    assert stats.magical_res == 36
    assert stats.physical_atk == 12
    assert stats.magical_atk == 241
  end

  test "uses ingested userstat values when available" do
    key = "table:userstat.xml"

    metadata = %{
      jobs: %{
        30 => %{
          "1" => %{strength: 1, dexterity: 1, intelligence: 14, luck: 1, health: 61},
          "70" => %{strength: 18, dexterity: 17, intelligence: 434, luck: 17, health: 2706}
        }
      }
    }

    :ets.insert(:metadata, {key, {:ok, metadata}})

    on_exit(fn -> :ets.delete(:metadata, key) end)

    assert %{strength: 18, dexterity: 17, intelligence: 434, luck: 17, health: 2706} =
             BaseStats.all(:wizard, 70)
  end

  test "attack formulas use job-specific primary coefficients" do
    assert AttackStats.physical_attack(:knight, 371, 62, 26) == 245
    assert AttackStats.physical_attack(:wizard, 17, 18, 17) == 12
    assert AttackStats.magical_attack(:wizard, 434) == 245
  end
end
