defmodule Ms2ex.Characters do
  alias Ms2ex.{Character, Inventory, Repo, Users.Account}

  import Ecto.Query, except: [update: 2]

  def create(%Account{} = account, attrs) do
    attrs = Map.put(attrs, :stats, %{})

    account
    |> Ecto.build_assoc(:characters)
    |> Character.changeset(attrs)
    |> Repo.insert()
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
