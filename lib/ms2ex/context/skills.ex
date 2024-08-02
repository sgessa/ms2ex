defmodule Ms2ex.Context.Skills do
  alias Ms2ex.{Context, Storage, Repo, Schema}

  import Ecto.Query, except: [update: 2]

  def by_job(job) do
    jobs = Storage.Tables.Jobs.all()

    basic_skills = get_in(jobs, [job, :skills, :basic]) || []
    awakening_skills = get_in(jobs, [job, :skills, :awakening]) || []
    skills = basic_skills ++ awakening_skills

    Enum.into(skills, [], & &1.main)
  end

  def get_active_tab(%Schema.Character{active_skill_tab_id: active_tab_id, skill_tabs: tabs}) do
    Enum.find(tabs, &(&1.id == active_tab_id))
  end

  def find_in_tab(%Schema.SkillTab{skills: skills}, skill_id) do
    Enum.find(skills, &(&1.skill_id == skill_id))
  end

  def add_tab(%Schema.Character{} = character, attrs) do
    attrs = Context.SkillTabs.set_skills(character.job, attrs)

    character
    |> Schema.SkillTab.add(attrs)
    |> Repo.insert()
  end

  def update_tab(%Schema.SkillTab{} = tab, attrs) do
    tab
    |> Schema.SkillTab.changeset(attrs)
    |> Repo.update()
  end

  def get_tab(%Schema.Character{skill_tabs: tabs}, tab_id) do
    Enum.find(tabs, &(&1.id == tab_id))
  end

  def load_tab_skills(%Schema.Character{job: job}, %Schema.SkillTab{id: tab_id}) do
    skills =
      Schema.Skill
      |> where([s], s.skill_tab_id == ^tab_id)
      |> Repo.all()
      |> Enum.into(%{}, &{&1.skill_id, &1})

    # Return skills ordered according to the character job
    ordered_ids = Context.SkillTabs.ordered_skill_ids(job)
    Enum.map(ordered_ids, &Map.get(skills, &1))
  end

  def find_and_update(%Schema.SkillTab{} = tab, skill_id, attrs) do
    case Repo.get_by(Schema.Skill, skill_tab_id: tab.id, skill_id: skill_id) do
      nil -> :error
      skill -> update(skill, attrs)
    end
  end

  def update(%Schema.Skill{} = skill, attrs) do
    skill
    |> Schema.Skill.changeset(attrs)
    |> Repo.update()
  end

  def update_subskills(character, skill_tab, parent_skill) do
    %Schema.Character{job: job} = character
    job_skill = Map.get(by_job(job), parent_skill.skill_id)

    Enum.each(job_skill.sub_skills, fn sub_skill_id ->
      if sub_skill = find_in_tab(skill_tab, sub_skill_id) do
        {:ok, _sub} = update(sub_skill, %{level: parent_skill.level})
      end
    end)
  end

  def load_metadata(%Schema.Skill{skill_id: skill_id} = skill) do
    metadata = Storage.Skills.get_meta(skill_id)
    Map.put(skill, :metadata, metadata)
  end
end
