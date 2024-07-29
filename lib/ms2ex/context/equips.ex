defmodule Ms2ex.Equips do
  alias Ms2ex.{Character, Inventory, Item, Items, Repo, Enums}

  import Ecto.Query, except: [update: 2]
  import Inventory, only: [update_item: 2, find_first_available_slot: 2]

  def list(%Character{id: char_id}) do
    Item
    |> where([i], i.character_id == ^char_id and i.location == ^:equipment)
    |> Repo.all()
    |> Enum.map(&Items.load_metadata(&1))
  end

  def find_equipped_in_slots(equips, slots, inventory_tab, requested_slot \\ nil)

  # When we are equipping pants, we need to check if we have a suit (CL) equipped
  def find_equipped_in_slots(equips, [:PA], inventory_tab, _requested_slot) do
    suit =
      Enum.find(equips, &(&1.metadata.slots == [:CL, :PA] and &1.inventory_tab == inventory_tab))

    slots =
      if suit do
        [:CL, :PA]
      else
        [:PA]
      end

    Enum.filter(equips, &(&1.equip_slot in slots and &1.inventory_tab == inventory_tab))
  end

  # When we are equipping off-hand weapons, we need to check against the slot requested by the client
  def find_equipped_in_slots(equips, slots, inventory_tab, requested_slot) when slots == [:OH] do
    Enum.filter(equips, &(&1.equip_slot == requested_slot and &1.inventory_tab == inventory_tab))
  end

  def find_equipped_in_slots(equips, slots, inventory_tab, _requested_slot) do
    Enum.filter(equips, &(&1.equip_slot in slots and &1.inventory_tab == inventory_tab))
  end

  def equip(%Item{metadata: meta} = item) do
    equip(item, List.first(meta.slot_names))
  end

  def equip(%Item{location: :inventory} = item, equip_slot) do
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
    !!Enums.EquipSlot.get_value(slot_name)
  rescue
    _ -> false
  end
end
