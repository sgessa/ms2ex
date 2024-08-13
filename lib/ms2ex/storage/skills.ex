defmodule Ms2ex.Storage.Skills do
  alias Ms2ex.Storage

  def get_region_skill(skill_id) do
    skill_id
    |> get_meta()
    |> Map.get(:region_skills)
    |> hd()
    |> Map.get(:block)
  end

  def get_effect(skill_id, skill_level) do
    Storage.get("additional-effect", "#{skill_id}_#{skill_level}")
  end

  def get_meta(skill_id) do
    Storage.get(:skill, skill_id)
  end
end
