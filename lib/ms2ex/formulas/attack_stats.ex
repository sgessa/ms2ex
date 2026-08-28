defmodule Ms2ex.Formulas.AttackStats do
  @primary 19.0 / 30.0
  @secondary 1.0 / 6.0
  @physical_coefficients %{
    knight: {@primary, @secondary, 0.0},
    berserker: {@primary, @secondary, 0.0},
    wizard: {0.5666, @secondary, 0.0},
    priest: {0.4721, @secondary, 0.0},
    archer: {@secondary, @primary, 0.0},
    heavy_gunner: {0.0, @primary, @secondary},
    thief: {@secondary, 0.0, @primary},
    assassin: {0.0, @secondary, @primary},
    rune_blade: {@primary, @secondary, 0.0},
    striker: {@secondary, @primary, 0.0},
    soul_binder: {0.5666, @secondary, 0.0}
  }
  @magical_coefficients %{
    knight: @primary,
    berserker: @primary,
    wizard: 0.5666,
    priest: 0.4721,
    archer: @primary,
    heavy_gunner: @primary,
    thief: @primary,
    assassin: @primary,
    rune_blade: 0.5666,
    striker: @primary,
    soul_binder: 0.5666
  }

  def physical_attack(job, strength, dexterity, luck) do
    {strength_coefficient, dexterity_coefficient, luck_coefficient} =
      Map.get(@physical_coefficients, job, {0.0, 0.0, 0.0})

    trunc(
      strength_coefficient * strength +
        dexterity_coefficient * dexterity +
        luck_coefficient * luck
    )
  end

  def magical_attack(job, intelligence) do
    coefficient = Map.get(@magical_coefficients, job, 0.0)

    trunc(coefficient * intelligence)
  end
end
