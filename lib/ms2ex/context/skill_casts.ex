defmodule Ms2ex.SkillCasts do
  alias Ms2ex.{Character, Field, SkillCast, SkillStatus, Stats}

  def cast(%Character{stats: stats} = character, %SkillCast{} = skill_cast) do
    sp_cost = SkillCast.sp_cost(skill_cast)
    stamina_cost = SkillCast.stamina_cost(skill_cast)

    if stats.spirit_cur >= sp_cost and stats.stamina_cur >= stamina_cost do
      character = Stats.consume_sp(character, sp_cost)
      character = Stats.consume_stamina(character, stamina_cost)

      character = %{character | skill_cast: skill_cast}

      # TODO send notice

      if SkillCast.owner_buff?(skill_cast) or SkillCast.entity_buff?(skill_cast) or
           SkillCast.shield_buff?(skill_cast) or SkillCast.owner_debuff?(skill_cast) do
        status = SkillStatus.new(skill_cast, character.object_id, character.object_id, 1)
        Field.add_status(character, status)
      end

      # TODO refresh out-of-combat timer

      character
    else
      character
    end
  end
end
