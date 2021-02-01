defmodule Ms2ex.Characters do
  alias Ms2ex.{Character, Inventory, Metadata, Repo, Skills, Users.Account}

  import Ecto.Query, except: [update: 2]

  def create(%Account{} = account, attrs) do
    attrs = Map.put(attrs, :skill_tabs, [%{name: "Build 1"}])
    attrs = Map.put(attrs, :stats, %{})

    changeset =
      account
      |> Ecto.build_assoc(:characters)
      |> Character.changeset(attrs)

    Repo.transaction(fn ->
      with {:ok, character} <- Repo.insert(changeset),
           :ok <- populate_skill_tab(character) do
        character
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  defp populate_skill_tab(character) do
    skill_tab = List.first(character.skill_tabs)
    job_skills = Skills.by_job(character.job)

    Enum.reduce_while(job_skills, :ok, fn {id, skill}, result ->
      meta = Metadata.Skills.get(id)
      skill_level = List.first(skill.skill_levels)

      with :ok <- result,
           {:ok, _skill} <-
             Skills.create(skill_tab, %{
               skill_id: id,
               learned: meta.learned,
               level: skill_level.level
             }) do
        {:cont, :ok}
      else
        error -> {:halt, error}
      end
    end)
  end

  def get(id), do: Repo.get(Character, id)

  def update(%Character{} = character, attrs) do
    character
    |> Character.changeset(attrs)
    |> Repo.update()
  end

  def delete(%Character{} = character), do: Repo.delete(character)

  def load_equips(%Character{} = character, opts \\ []) do
    equips = where(Inventory.Item, [i], i.location == ^:equipment)
    Repo.preload(character, [equips: equips], opts)
  end

  def preload(%Character{} = character, assocs) do
    Repo.preload(character, assocs)
  end
end
