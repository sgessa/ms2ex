defmodule Ms2ex.ItemStatsTest do
  use ExUnit.Case, async: true

  alias Ms2ex.Context.ItemStats
  alias Ms2ex.Formulas.GearScore

  defp character do
    %Ms2ex.Schema.Character{
      stats: %{
        physical_atk_cur: 10,
        physical_atk_max: 10,
        physical_atk_min: 10,
        min_weapon_atk_cur: 0,
        min_weapon_atk_min: 0,
        min_weapon_atk_max: 0,
        health_cur: 500,
        health_max: 500
      }
    }
  end

  test "applies bonuses to current and max stats" do
    character = ItemStats.apply_stats(character(), %{physical_atk: 40, health: 250})

    assert character.stats.physical_atk_cur == 50
    assert character.stats.physical_atk_max == 50
    assert character.stats.physical_atk_min == 10
    assert character.stats.health_cur == 750
    assert character.stats.health_max == 750
  end

  test "no bonuses leaves stats unchanged" do
    assert ItemStats.apply_stats(character(), %{}).stats.physical_atk_cur == 10
  end

  test "bonuses accumulate with existing gear" do
    character = ItemStats.apply_stats(character(), %{min_weapon_atk: 150})
    character = ItemStats.apply_stats(character, %{min_weapon_atk: 50})

    assert character.stats.min_weapon_atk_cur == 200
    assert character.stats.min_weapon_atk_min == 0
  end

  test "calculates NA gear score for an enchanted rarity four weapon" do
    assert GearScore.item_level(67, 4, 33, 10, 0) == {8355, 4177}
  end

  test "uses the common enchant table below rarity four" do
    assert GearScore.item_level(67, 3, 33, 10, 0) == {680, 299}
  end

  test "uses the NA enchant table for rarity five below limit break 60" do
    assert GearScore.item_level(67, 5, 33, 10, 0) == {17_968, 8_984}
  end

  test "halves throwing star gear score after item level calculation" do
    item = %{gear_score: 67, rarity: 4, item_type: 34, enchant_level: 10, limit_break_level: 0}

    assert GearScore.calculate([item]) == 6266
  end

  test "does not count shields and spellbooks toward gear score" do
    items =
      for item_type <- [40, 41], do: %{gear_score: 67, rarity: 4, item_type: item_type}

    assert GearScore.calculate(items) == 0
  end
end
