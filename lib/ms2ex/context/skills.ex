defmodule Ms2ex.Skills do
  alias Ms2ex.{Character, Metadata, Repo, Skill, SkillTab}

  import Ecto.Query, except: [update: 2]

  @climbing_id 20_000_011
  @swimming_id 20_000_001
  @common_skills [@climbing_id, @swimming_id]

  def by_job(job) do
    skills = Metadata.all(Ms2ex.Metadata.Skill)

    Enum.reduce(skills, %{}, fn skill, acc ->
      level = skill.levels |> Enum.at(0) |> elem(1)

      # TODO: job_code is always [], probably not the right field

      cond do
        job in level.condition.job_code or skill.id in @common_skills ->
          Map.put(acc, skill.id, skill)

        true ->
          acc
      end
    end)
  end

  def get_active_tab(%Character{skill_tabs: tabs} = character) do
    %{active_skill_tab_id: tab_id} = character
    Enum.find(tabs, &(&1.id == tab_id))
  end

  def find_in_tab(%SkillTab{skills: skills}, skill_id) do
    Enum.find(skills, &(&1.skill_id == skill_id))
  end

  def add_tab(%Character{} = character, attrs) do
    attrs = SkillTab.set_skills(character.job, attrs)

    character
    |> SkillTab.add(attrs)
    |> Repo.insert()
  end

  def update_tab(%SkillTab{} = tab, attrs) do
    tab
    |> SkillTab.changeset(attrs)
    |> Repo.update()
  end

  def get_tab(%Character{skill_tabs: tabs}, tab_id) do
    Enum.find(tabs, &(&1.id == tab_id))
  end

  def load_tab_skills(%Character{job: job}, %SkillTab{id: tab_id}) do
    skills =
      Skill
      |> where([s], s.skill_tab_id == ^tab_id)
      |> Repo.all()
      |> Enum.into(%{}, &{&1.skill_id, &1})

    # Return skills ordered according to the character job
    ordered_ids = SkillTab.ordered_skill_ids(job)
    Enum.map(ordered_ids, &Map.get(skills, &1))
  end

  def find_and_update(%SkillTab{} = tab, skill_id, attrs) do
    case Repo.get_by(Skill, skill_tab_id: tab.id, skill_id: skill_id) do
      %Skill{} = skill -> update(skill, attrs)
      nil -> :error
    end
  end

  def update(%Skill{} = skill, attrs) do
    skill
    |> Skill.changeset(attrs)
    |> Repo.update()
  end

  def update_subskills(%Character{job: job}, %SkillTab{} = tab, %Skill{} = parent) do
    job_skill = Map.get(by_job(job), parent.skill_id)

    Enum.each(job_skill.sub_skills, fn sub_id ->
      if sub = find_in_tab(tab, sub_id) do
        {:ok, _sub} = update(sub, %{level: parent.level})
      end
    end)
  end

  def load_metadata(%Skill{skill_id: skill_id} = skill) do
    metadata = Metadata.get(Metadata.Skill, skill_id)
    Map.put(skill, :metadata, metadata)
  end
end
