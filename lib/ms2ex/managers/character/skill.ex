defmodule Ms2ex.Managers.Character.Skill do
  alias Ms2ex.Context
  alias Ms2ex.Types

  alias Ms2ex.Managers
  alias Ms2ex.Managers.Character

  def cast_skill(%{stats: stats} = character, skill_cast) do
    spirit_cost = Types.SkillCast.spirit_cost(skill_cast)
    stamina_cost = Types.SkillCast.stamina_cost(skill_cast)

    # Ensure player has enough spirit & stamina
    if stats.spirit_cur >= spirit_cost && stats.stamina_cur >= stamina_cost do
      cast_skill(character, skill_cast, spirit_cost, stamina_cost)
    else
      character
    end
  end

  def cast_skill(character, skill_cast, spirit_cost, stamina_cost) do
    for effect <- Types.SkillCast.skill_level(skill_cast).skills do
      for skill <- effect.skills do
        send(character.field_pid, {:add_buff, skill_cast, skill, character})
      end
    end

    Context.Field.enter_battle_stance(character)

    character
    |> Character.Stats.decrease(:spirit, spirit_cost)
    |> Character.Stats.decrease(:stamina, stamina_cost)
    |> add(skill_cast)
  end

  def add(character, skill_cast) do
    skill_casts = Map.put(character.skill_casts, skill_cast.id, skill_cast)
    %{character | skill_casts: skill_casts}
  end

  def update(character, skill_cast, attrs) do
    skill_cast = character.skill_casts |> Map.get(skill_cast.id) |> Map.merge(attrs)
    character = add(character, skill_cast)
    Managers.Character.update(character)

    {:ok, character, skill_cast}
  end
end
