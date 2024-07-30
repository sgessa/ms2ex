defmodule Ms2ex.Storage.Skills do
  alias Ms2ex.Storage.Metadata

  def get_region_skill(skill_id) do
    skill_id
    |> get_meta()
    |> Map.get(:region_skills)
    |> hd()
    |> Map.get(:block)
  end

  def get_duration(skill_id) do
    skill_id
    |> get_meta()
    |> Map.get(:additional_effects)
    |> case do
      nil -> 5_000
      ae -> Map.get(hd(ae), :interval)
    end
  end

  def get_meta(skill_id) do
    Metadata.get(:skill, skill_id)
  end
end
