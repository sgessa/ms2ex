defmodule Ms2ex.Context.Damage do
  alias Ms2ex.{Schema, SkillCast}
  alias Ms2ex.Types.FieldNpc

  def roll_crit(%Schema.Character{} = character) do
    crit_rate = character.stats.critical_rate_cur + 50
    crit_rate = crit_rate |> max(0) |> min(400)
    Enum.random(1..1000) <= crit_rate
  end

  def calculate(%Schema.Character{} = caster, %FieldNpc{} = mob, crit? \\ false) do
    skill_cast = caster.skill_cast

    # TODO calculate from character stats
    attk_dmg = 300

    skill_dmg_rate =
      if crit?,
        do: SkillCast.crit_damage_rate(skill_cast),
        else: SkillCast.damage_rate(skill_cast)

    skill_dmg = skill_dmg_rate * attk_dmg

    enemy_res = calc_enemy_res(skill_cast, mob)
    pierce_res = calc_pierce_res(skill_cast, caster)

    # TODO fix dmg multiplier
    numerator =
      skill_dmg * (1 + caster.stats.bonus_atk_cur) * (1500 - (enemy_res - pierce_res * 15))

    pierce_coeff = 1 - caster.stats.piercing_cur

    # TODO find correct enemy def stats
    denominator = mob.stats.defense.total * pierce_coeff * 15

    dmg = trunc(numerator / denominator)
    %{dmg: dmg, crit?: crit?}
  end

  defp calc_enemy_res(skill_cast, mob) do
    if SkillCast.physical?(skill_cast) do
      mob.stats.physical_res.total
    else
      mob.stats.magical_res.total
    end
  end

  defp calc_pierce_res(skill_cast, caster) do
    if SkillCast.physical?(skill_cast) do
      caster.stats.physical_atk_cur
    else
      caster.stats.magical_atk_cur
    end
  end

  @fall_dmg 150
  def calculate_fall_dmg(%Schema.Character{}) do
    @fall_dmg
  end
end
