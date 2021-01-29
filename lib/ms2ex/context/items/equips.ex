defmodule Ms2ex.Equips do
  alias Ms2ex.{Character, Inventory, Metadata, Repo}
  alias Inventory.Item

  import Ecto.Query, except: [update: 2]
  import Inventory, only: [update_item: 2, determine_inventory_slot: 1]

  def list(%Character{id: char_id}) do
    Item
    |> where([i], i.character_id == ^char_id and i.location == ^:equipment)
    |> Repo.all()
    |> Enum.map(&Metadata.Items.load(&1))
  end

  # For suits, check top and pants
  def find_equipped_in_slot(equips, %{metadata: %{slot: :CL, is_two_handed: true}}) do
    Enum.filter(equips, &(&1.metadata.slot == :CL || &1.metadata.slot == :PA))
  end

  # For top or pants, we have to check if a dress is equipped
  def find_equipped_in_slot(equips, %{metadata: %{slot: slot}}) when slot in [:CL, :PA] do
    Enum.filter(equips, fn e ->
      (e.metadata.is_two_handed && e.metadata.slot == :CL) || e.metadata.slot == slot
    end)
  end

  # For one-hand weapon, check left-hand and right-hand weapons
  def find_equipped_in_slot(equips, %{metadata: %{slot: :RH, is_two_handed: true}}) do
    Enum.filter(equips, &(&1.metadata.slot == :LH || &1.metadata.slot == :RH))
  end

  def find_equipped_in_slot(equips, %{metadata: %{slot: slot}}) do
    Enum.filter(equips, &(&1.metadata.slot == slot))
  end

  def equip(%Item{location: :inventory} = item) do
    update_item(item, %{location: :equipment})
  end

  def unequip(%Item{} = item) do
    with slot <- determine_inventory_slot(item),
         {:ok, item} <- update_item(item, %{location: :inventory, inventory_slot: slot}) do
      {:ok, item}
    else
      %Item{location: :inventory} ->
        {:error, :item_not_equipped}

      nil ->
        {:error, :item_not_found}
    end
  end
end
