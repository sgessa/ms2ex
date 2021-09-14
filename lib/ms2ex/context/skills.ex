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

    Enum.reduce(skills, %{}, fn {id, meta}, acc ->
      cond do
        meta.job == job ->
          Map.put(acc, id, meta)

        meta.id == @swimming_id or meta.id == @climbing_id ->
          Map.put(acc, id, %{meta | starting_level: 1})

        true ->
          acc
      end
    end)
  end

  def get_active_tab(%Character{skill_tabs: tabs} = character) do
    %{active_skill_tab_id: tab_id} = character
    Enum.find(tabs, &(&1.tab_id == tab_id))
  end

  def add_tab(%Character{} = character) do
    %{job: job, skill_tabs: tabs} = character

    new_tab_id = length(tabs) + 1
    name = "Build #{new_tab_id}"
    attrs = SkillTab.set_skills(job, %{name: name, tab_id: new_tab_id})
    changes = SkillTab.add(character, attrs)

    with {:ok, new_tab} <- Repo.insert(changes) do
      {:ok, Map.put(character, :skill_tabs, tabs ++ [new_tab])}
    end
  end

  def get_tab(%Character{skill_tabs: tabs}, tab_id) do
    Enum.find(tabs, &(&1.id == tab_id))
  end

  def load_tab_skills(%Character{id: char_id, job: job}, %SkillTab{id: tab_id}) do
    skills =
      Skill
      |> join(:inner, [s], t in assoc(s, :skill_tab))
      |> where([s, t], t.character_id == ^char_id and s.skill_tab_id == ^tab_id)
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

  def reset(%Character{} = character, %SkillTab{} = tab) do
    attrs = %{skills: SkillTab.set_skills(character.job)}
    changes = SkillTab.reset(tab, attrs)

    case Repo.update(changes) do
      {:ok, tab} ->
        case Enum.find_index(character.skill_tabs, &(&1.id == tab.id)) do
          nil ->
            character

          index ->
            skill_tabs = List.update_at(character.skill_tabs, index, fn _ -> tab end)
            %{character | skill_tabs: skill_tabs}
        end

      _ ->
        character
    end
  end
end
