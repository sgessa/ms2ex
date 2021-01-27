defmodule Ms2ex.Skills do
  alias Ms2ex.SkillTab
  alias Ms2ex.Metadata.SkillMetadata

  @first_tab_id 0x000032DF995949B9
  @climbing_id 20_000_011
  @swimming_id 20_000_001
  @metadata_table :skill_metadata

  def metadata(skill_id) do
    case :ets.lookup(@metadata_table, skill_id) do
      [{_id, %SkillMetadata{} = meta}] -> meta
      _ -> nil
    end
  end

  def by_job(job) do
    skills = :ets.tab2list(@metadata_table)

    skills
    |> Enum.filter(fn {_id, meta} ->
      meta.job == job or meta.id == @swimming_id or meta.id == @climbing_id
    end)
    |> Enum.into(%{}, fn {id, meta} -> {id, meta} end)
  end

  def get_tab(job) do
    name = "Build"
    ordered = SkillTab.ordered_skills(job)
    %{id: @first_tab_id, name: name, skills: by_job(job), ordered_ids: ordered}
  end
end
