defmodule Ms2ex.Characters do
  alias Ms2ex.{Account, Character, Repo}

  import Ecto.Query

  def list(%Account{id: account_id}) do
    Character
    |> where([c], c.account_id == ^account_id)
    |> Repo.all()
    |> Enum.map(&load_equips(&1))
  end

  def create(%Account{} = account, attrs) do
    attrs = Character.set_default_assocs(attrs)

    changeset =
      account
      |> Ecto.build_assoc(:characters)
      |> Character.changeset(attrs)

    Repo.transaction(fn ->
      with {:ok, character} <- Repo.insert(changeset) do
        character
      else
        {:error, reason} -> Repo.rollback(reason)
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
