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

  def find_equipped_in_slot(equips, slots) do
    Enum.filter(equips, &(&1.equip_slot in slots))
  end

  def equip(equip_slots, item) when is_list(equip_slots) do
    equip(List.first(equip_slots), item)
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
    Map.has_key?(Metadata.Items.EquipSlot.mapping(), slot_name)
  rescue
    _ -> false
  end
end
