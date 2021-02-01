defmodule Ms2ex.Skills do
  alias Ms2ex.{Character, Metadata, Repo, Skill, SkillTab}

  import Ecto.Query, except: [update: 2]

  @climbing_id 20_000_011
  @swimming_id 20_000_001
  @metadata_table :skill_metadata

  def metadata(skill_id) do
    case :ets.lookup(@metadata_table, skill_id) do
      [{_id, %Metadata.Skill{} = meta}] -> meta
      _ -> nil
    end
  end

  def by_job(job) do
    skills = :ets.tab2list(@metadata_table)

    Enum.filter(skills, fn {_id, meta} ->
      meta.job == job or meta.id == @swimming_id or meta.id == @climbing_id
    end)
  end

  def find_and_update(%SkillTab{} = tab, skill_id, attrs) do
    case Repo.get_by(Skill, skill_tab_id: tab.id, skill_id: skill_id) do
      %Skill{} = skill -> update(skill, attrs)
      nil -> :error
    end
  end

  def create(tab, attrs) do
    tab
    |> Ecto.build_assoc(:skills)
    |> Skill.changeset(attrs)
    |> Repo.insert()
  end

  def update(%Skill{} = skill, attrs) do
    skill
    |> Skill.changeset(attrs)
    |> Repo.update()
  end

  def get_tab(%{id: character_id}) do
    SkillTab
    |> where([t], t.character_id == ^character_id)
    |> limit(1)
    |> Repo.one()
  end

  def list(%Character{job: job}, %SkillTab{id: tab_id}) do
    character_skills =
      Skill
      |> where([s], s.skill_tab_id == ^tab_id)
      |> Repo.all()
      |> Enum.into(%{}, &{&1.skill_id, &1})

    ordered_ids = SkillTab.ordered_skill_ids(job)

    Enum.map(ordered_ids, &Map.get(character_skills, &1))
  end

  def reset(%Character{} = character, %SkillTab{} = tab) do
    skills = list(character, tab)

    Enum.each(skills, fn skill ->
      meta = Metadata.Skills.get(skill.skill_id)
      skill_level = List.first(meta.skill_levels)
      learned = meta.learned
      update(skill, %{learned: learned, level: skill_level.level})
    end)
  end
end
