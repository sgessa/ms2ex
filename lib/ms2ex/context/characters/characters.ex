defmodule Ms2ex.Characters do
  alias Ms2ex.{Character, Inventory, Repo, Users.Account}

  def create(%Account{} = account, attrs) do
    account
    |> Ecto.build_assoc(:characters)
    |> Character.changeset(attrs)
    |> Repo.insert()
  end

  def get(id), do: Repo.get(Character, id)

  def load_equips(%Character{} = character) do
    character =
      Repo.preload(character, equipment: [:face, :face_decor, :hair, :top, :bottom, :shoes])

    e = character.equipment

    equips =
      [e.face, e.face_decor, e.hair, e.top, e.bottom, e.shoes]
      |> Enum.reject(&is_nil(&1))
      |> Enum.map(&Inventory.load_metadata(&1))

    Map.put(character, :equips, equips)
  end
end
