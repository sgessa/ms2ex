defmodule Ms2ex.ItemStatsTest do
  use ExUnit.Case, async: true

  alias Ms2ex.Context.ItemStats

  defp character do
    %Ms2ex.Schema.Character{
      stats: %{
        physical_atk_cur: 10,
        physical_atk_max: 10,
        min_weapon_atk_cur: 0,
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
  end
end
