defmodule Ms2ex.Equips do
  alias Ms2ex.{Character, Inventory.Item, Repo}

  def set_equip(%Character{} = char, %Item{} = equip) do
    char
    |> Repo.preload(:equipment)
    |> Character.set_equip(equip)
    |> Repo.update()
  end
end
