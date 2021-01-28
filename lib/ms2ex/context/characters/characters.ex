defmodule Ms2ex.Characters do
  alias Ms2ex.{Character, Inventory, Repo, Users.Account}

  import Ecto.Query, except: [update: 2]

  def create(%Account{} = account, attrs) do
    account
    |> Ecto.build_assoc(:characters)
    |> Character.changeset(attrs)
    |> Repo.insert()
  end

  def get(id), do: Repo.get(Character, id)

  def load_equips(%Character{} = character, opts \\ []) do
    equips = where(Inventory.Item, [i], i.location == ^:equipment)
    Repo.preload(character, [equips: equips], opts)
  end

  def delete(%Character{} = character), do: Repo.delete(character)
end
