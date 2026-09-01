defmodule Ms2ex.DamageTest do
  use ExUnit.Case, async: true

  alias Ms2ex.Context.Damage
  alias Ms2ex.Schema.Character
  alias Ms2ex.Types.FieldNpc

  test "applies zero-piercing defense multiplier" do
    damage = Damage.calculate_rate(1.0, caster(), mob(), true)

    assert damage.dmg == 20_000
  end

  test "uses critical damage scaling" do
    normal = Damage.calculate_rate(1.0, caster(), mob(), true)
    critical = Damage.calculate_rate(1.0, caster(), mob(), true, true)

    assert critical.dmg == trunc(normal.dmg * 1.125)
  end

  defp caster do
    %Character{
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
    }
  end

  defp mob do
    %FieldNpc{
      stats: %{
        defense: %{total: 10},
        physical_res: %{total: 0},
        magical_res: %{total: 0}
      }
    }
  end
end
