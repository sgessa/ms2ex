defmodule Ms2ex.Damage do
  alias Ms2ex.{Character, Characters, Mob, SkillCast}

  import Access, only: [key!: 1]

  def roll_crit(%Character{} = character) do
    crit_rate = character.stats.crit_rate_cur + 50
    crit_rate = crit_rate |> max(0) |> min(400)
    Enum.random(1..1000) <= crit_rate
  end

  def calculate(%Character{} = caster, %Mob{} = mob, crit? \\ false) do
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
      skill_dmg * (1 + caster.stats.bonus_attk_cur) * (1500 - (enemy_res - pierce_res * 15))

    pierce_coeff = 1 - caster.stats.pierce_cur

    # TODO find correct enemy def stats
    denominator = mob.stats.cad.total * pierce_coeff * 15

    dmg = trunc(numerator / denominator)
    %{dmg: dmg, crit?: crit?}
  end

  defp calc_enemy_res(skill_cast, mob) do
    if SkillCast.physical?(skill_cast) do
      mob.stats.phys_res.total
    else
      mob.stats.mag_res.total
    end
  end

  defp calc_pierce_res(skill_cast, caster) do
    if SkillCast.physical?(skill_cast) do
      caster.stats.phys_attk_cur
    else
      caster.stats.magic_attk_cur
    end
  end

  def receive_fall_dmg(%Character{stats: %{current_hp_min: hp}} = character) do
    dmg = calculate_fall_dmg(character)
    hp = max(hp - dmg, 25)
    update_health(character, hp)
  end

  @fall_dmg 150
  defp calculate_fall_dmg(%Character{position: %{z: _height}}) do
    @fall_dmg
  end

  defp update_health(%Character{stats: stats} = character, health) do
    stats = Map.delete(stats, :__struct__)
    stats = %{stats | hp_cur: health}
    {:ok, character} = Characters.update(character, %{stats: stats})
    character
  end

  defp update_health(obj, health) do
    update_in(obj, [key!(:stats), key!(:hp), key!(:max)], fn _ -> health end)
  end
end
