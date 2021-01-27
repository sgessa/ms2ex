defmodule Ms2ex.Characters do
  alias Ms2ex.{Character, Inventory, Repo, Users.Account}

  def create(%Account{} = account, attrs) do
    account
    |> Ecto.build_assoc(:characters)
    |> Character.changeset(attrs)
    |> Repo.insert()
  end

  def get(id), do: Repo.get(Character, id)

  def load_equips(%Character{} = character, opts \\ []) do
    character =
      Repo.preload(
        character,
        [equipment: [:ears, :hair, :face, :face_decor, :top, :bottom, :shoes]],
        opts
      )

    e = character.equipment

    equips =
      [e.ears, e.hair, e.face, e.face_decor, e.top, e.bottom, e.shoes]
      |> Enum.reject(&is_nil(&1))
      |> Enum.map(&Inventory.load_metadata(&1))

    Map.put(character, :equips, equips)
  end

  def delete(%Character{} = character), do: Repo.delete(character)
end
