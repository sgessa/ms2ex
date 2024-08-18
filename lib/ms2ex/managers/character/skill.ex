defmodule Ms2ex.Managers.Character.Skill do
  alias Ms2ex.Context
  alias Ms2ex.Types

  alias Ms2ex.Managers

  def cast_skill(%{stats: stats} = character, skill_cast) do
    spirit_cost = Types.SkillCast.spirit_cost(skill_cast)
    stamina_cost = Types.SkillCast.stamina_cost(skill_cast)

    # Ensure player has enough spirit & stamina
    if stats.spirit_cur >= spirit_cost && stats.stamina_cur >= stamina_cost do
      character = use_skill(character, skill_cast, spirit_cost, stamina_cost)
      {:ok, character}
    else
      {:error, character}
    end
  end

  def use_skill(character, skill_cast, spirit_cost, stamina_cost) do
    for effect <- Types.SkillCast.skill_level(skill_cast).skills do
      for skill <- effect.skills do
        send(character.field_pid, {:add_buff, character, skill_cast, skill})
      end
    end

    Context.Field.enter_battle_stance(character)

    character
    |> Managers.Character.Stats.decrease(:spirit, spirit_cost)
    |> Managers.Character.Stats.decrease(:stamina, stamina_cost)
    |> add(skill_cast)
  end

  def add(character, skill_cast) do
    skill_casts = Map.put(character.skill_casts, skill_cast.id, skill_cast)
    %{character | skill_casts: skill_casts}
  end
end
