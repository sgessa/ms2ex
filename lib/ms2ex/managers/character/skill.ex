defmodule Ms2ex.Managers.Character.Skill do
  alias Ms2ex.Context
  alias Ms2ex.Types

  alias Ms2ex.Managers
  alias Ms2ex.Managers.Character

  def cast_skill(%{stats: stats} = character, skill_cast) do
    sp_cost = Types.SkillCast.spirit_cost(skill_cast)
    sta_cost = Types.SkillCast.stamina_cost(skill_cast)

    # Ensure player has enough spirit & stamina
    if stats.spirit_cur >= sp_cost and stats.stamina_cur >= sta_cost do
      cast_skill(character, skill_cast, sp_cost, sta_cost)
    else
      character
    end
  end

  def cast_skill(character, skill_cast, sp_cost, sta_cost) do
    Managers.SkillCast.start(skill_cast)

    for effect <- Types.SkillCast.skill_level(skill_cast).skills do
      for skill <- effect.skills do
        Context.Field.call(character, {:add_buff, skill_cast, skill, character})
      end
    end

    Context.Field.enter_battle_stance(character)

    character
    |> Character.Stats.decrease(:spirit, sp_cost)
    |> Character.Stats.decrease(:stamina, sta_cost)
  end
end
