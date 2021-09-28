defmodule Ms2ex.Equips do
  alias Ms2ex.{Character, Inventory, Item, Metadata, Repo}

  import Ecto.Query, except: [update: 2]
  import Inventory, only: [update_item: 2, find_first_available_slot: 2]

  def list(%Character{id: char_id}) do
    Item
    |> where([i], i.character_id == ^char_id and i.location == ^:equipment)
    |> Repo.all()
    |> Enum.map(&Metadata.Items.load(&1))
  end

  # For suits, check top and pants
  def find_equipped_in_slot(equips, :CL, %{metadata: %{is_dress?: true}}) do
    Enum.filter(equips, &(&1.equip_slot == :CL || &1.equip_slot == :PA))
  end

  # For top or pants, we have to check if a dress is equipped
  def find_equipped_in_slot(equips, slot, _item) when slot in [:CL, :PA] do
    Enum.filter(equips, fn e ->
      (e.metadata.is_dress? && e.equip_slot == :CL) || e.equip_slot == slot
    end)
  end

  # For one-hand weapon, check left-hand and right-hand weapons
  def find_equipped_in_slot(equips, :RH, %{metadata: %{is_two_handed?: true}}) do
    Enum.filter(equips, &(&1.equip_slot == :LH || &1.equip_slot == :RH))
  end

  # For left-hand weapon, we have to check if a two-hand weapon is equipped
  def find_equipped_in_slot(equips, slot, _item) when slot in [:LH, :RH] do
    Enum.filter(equips, fn e ->
      (e.metadata.is_two_handed? && e.equip_slot == :RH) || e.equip_slot == slot
    end)
  end

  def find_equipped_in_slot(equips, slot, _item) do
    Enum.filter(equips, &(&1.equip_slot == slot))
  end

  def equip(equip_slot, %Item{location: :inventory} = item) do
    update_item(item, %{equip_slot: equip_slot, inventory_slot: nil, location: :equipment})
  end

  def unequip(%Item{} = item) do
    with slot <- find_first_available_slot(item.character_id, item.inventory_tab),
         {:ok, item} <-
           update_item(item, %{equip_slot: :NONE, inventory_slot: slot, location: :inventory}) do
      {:ok, item}
    else
      %Item{location: :inventory} ->
        {:error, :item_not_equipped}

      nil ->
        {:error, :item_not_found}
    end
  end

  def valid_slot?(slot_name) do
    slot_name = String.to_existing_atom(slot_name)
    Map.has_key?(Metadata.EquipSlot.mapping(), slot_name)
  rescue
    _ -> false
  end
end
