defmodule Ms2ex.SkillCasts do
  alias Ms2ex.{Character, Field, SkillCast, SkillStatus, StatsManager, World}

  def cast(%Character{} = character, %SkillCast{} = skill_cast) do
    sp_cost = SkillCast.sp_cost(skill_cast)
    stamina_cost = SkillCast.stamina_cost(skill_cast)

    {:ok, stats} = StatsManager.lookup(character)

    if stats.sp_cur >= sp_cost and stats.sta_cur >= stamina_cost do
      StatsManager.consume(character, :sp, sp_cost)
      StatsManager.consume(character, :sta, stamina_cost)

      if SkillCast.owner_buff?(skill_cast) or SkillCast.entity_buff?(skill_cast) or
           SkillCast.shield_buff?(skill_cast) or SkillCast.owner_debuff?(skill_cast) do
        status = SkillStatus.new(skill_cast, character.object_id, character.object_id, 1)
        Field.add_status(character, status)
      end

      character = %{character | skill_cast: skill_cast}
      World.update_character(character)

      Field.enter_battle_stance(character)
    end
  end
end
