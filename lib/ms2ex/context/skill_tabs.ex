defmodule Ms2ex.Context.SkillTabs do
  alias Ms2ex.Storage
  alias Ms2ex.Context

  def set_skills(job, attrs \\ %{}) do
    job = Storage.Tables.Jobs.get(job)

    skills =
      job.skills
      |> Enum.reject(fn {rank, _skills} -> rank == :awakening && !Context.Jobs.awakening?(job) end)
      |> Enum.flat_map(fn {rank, skills} ->
        skills
        |> Enum.map(&{&1, Storage.Skills.get_meta(&1.main)})
        |> Enum.reject(fn {_skill, metadata} -> is_nil(metadata) end)
        |> Enum.map(&build_main_skill(&1, rank, job))
      end)

    Map.put(attrs, :skills, skills)
  end

  defp build_main_skill({skill, metadata}, rank, job) do
    base_skills = job.base_skills
    base_level = if skill.main in base_skills, do: 1, else: 0

    sub_skills = build_sub_skills(skill, rank, base_level)

    %{
      skill_id: skill.main,
      level: base_level,
      sub_skills: sub_skills,
      rank: rank,
      max_level: metadata.property.max_level
    }
  end

  defp build_sub_skills(skill, rank, base_level) do
    skill.sub
    |> Enum.map(&Storage.Skills.get_meta/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.map(fn sub ->
      %Ms2ex.Schema.Skill{
        skill_id: sub.id,
        level: base_level,
        max_level: sub.property.max_level,
        rank: rank
      }
    end)
  end
end
