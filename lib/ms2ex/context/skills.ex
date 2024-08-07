defmodule Ms2ex.Context.Skills do
  alias Ms2ex.{Context, Storage, Repo, Schema}

  import Ecto.Query, except: [update: 2]

  def by_job(job) do
    jobs = Storage.Tables.Jobs.all()

    basic_skills = get_in(jobs, [job, :skills, :basic]) || []
    awakening_skills = get_in(jobs, [job, :skills, :awakening]) || []

    basic_skills ++ awakening_skills
  end

  def get_active_tab(%Schema.Character{active_skill_tab_id: active_tab_id, skill_tabs: tabs}) do
    Enum.find(tabs, &(&1.id == active_tab_id))
  end

  def find_in_tab(%Schema.SkillTab{skills: skills}, skill_id) do
    Enum.find(skills, &(&1.skill_id == skill_id))
  end

  def add_tab(%Schema.Character{} = character, attrs) do
    attrs = Context.SkillTabs.set_skills(character.job, attrs, character.awakened)

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

  def load_tab_skills(%Schema.Character{job: _job}, %Schema.SkillTab{id: tab_id}) do
    Schema.Skill
    |> where([s], s.skill_tab_id == ^tab_id)
    |> Repo.all()
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

  def load_metadata(%Schema.Skill{skill_id: skill_id} = skill) do
    metadata = Storage.Skills.get_meta(skill_id)
    Map.put(skill, :metadata, metadata)
  end
end
