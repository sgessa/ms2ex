defmodule Ms2ex.Characters do
  alias Ms2ex.{Character, Emotes, Metadata, Repo, Skills, Account}

  import Ecto.Query

  def list(%Account{id: account_id}) do
    Character
    |> where([c], c.account_id == ^account_id)
    |> Repo.all()
    |> Enum.map(&load_equips(&1))
  end

  def create(%Account{} = account, attrs) do
    emotes = Enum.map(Emotes.default_emotes(), &%{emote_id: &1})
    attrs = Map.put(attrs, :emotes, emotes)

    attrs = Map.put(attrs, :hot_bars, [%{active: true}, %{}, %{}])
    attrs = Map.put(attrs, :skill_tabs, [%{name: "Build 1"}])
    attrs = Map.put(attrs, :stats, %{})
    attrs = Map.put(attrs, :wallet, %{})

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

      attrs = %{
        skill_id: id,
        learned: meta.learned,
        level: skill_level.level
      }

      with :ok <- result,
           {:ok, _skill} <- Skills.create(skill_tab, attrs) do
        {:cont, :ok}
      else
        error -> {:halt, error}
      end
    end)
  end

  def get(%Account{id: account_id}, character_id) do
    Repo.get_by(Character, account_id: account_id, id: character_id)
  end

  def get(id), do: Repo.get(Character, id)

  def update(%Character{} = character, attrs) do
    character
    |> Character.changeset(attrs)
    |> Repo.update()
  end

  def delete(%Character{} = character), do: Repo.delete(character)

  def preload(%Character{} = character, assocs) do
    Repo.preload(character, assocs)
  end

  def load_equips(%Character{} = character) do
    %{character | equips: Ms2ex.Equips.list(character)}
  end

  def list_titles(%Character{id: character_id}) do
    Ms2ex.CharacterTitle
    |> where([t], t.character_id == ^character_id)
    |> select([t], t.title_id)
    |> Repo.all()
  end

  def get_wallet(%Character{id: character_id}) do
    Ms2ex.Wallet
    |> where([w], w.character_id == ^character_id)
    |> limit(1)
    |> Repo.one()
  end
end
