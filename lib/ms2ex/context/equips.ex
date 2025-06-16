defmodule Ms2ex.Context.Equips do
  @moduledoc """
  Context module for equipment-related operations.

  This module provides functions for listing, equipping, and unequipping items,
  as well as validating equipment slots.
  """

  alias Ms2ex.{Context, Schema, Repo, Enums}

  import Ecto.Query, except: [update: 2]
  import Context.Inventory, only: [update_item: 2, find_first_available_slot: 2]

  @doc """
  Lists all equipped items for a given character.

  Returns a list of items with their metadata loaded.

  ## Examples

      iex> list(character)
      [%Schema.Item{location: :equipment, ...}, ...]
  """
  @spec list(Schema.Character.t()) :: [Schema.Item.t()]
  def list(%Schema.Character{id: char_id}) do
    Schema.Item
    |> where([i], i.character_id == ^char_id and i.location == ^:equipment)
    |> Repo.all()
    |> Enum.map(&Context.Items.load_metadata(&1))
  end

  @doc """
  Finds items that are equipped in specific slots.

  Handles special cases for pants (checking for suits) and off-hand weapons.

  ## Parameters

    * `equips` - List of equipped items to search through
    * `slots` - List of slot types to check
    * `inventory_tab` - The inventory tab to filter by
    * `requested_slot` - Optional specific slot requested (used for off-hand weapons)

  ## Examples

      iex> find_equipped_in_slots(equips, [:HD], :outfit)
      [%Schema.Item{equip_slot: :HD, ...}]
  """
  @spec find_equipped_in_slots(
          [Schema.Item.t()],
          [atom()],
          atom(),
          atom() | nil
        ) :: [Schema.Item.t()]
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

  @doc """
  Equips an item using its first available slot.

  ## Examples

      iex> equip(item)
      {:ok, %Schema.Item{location: :equipment, ...}}
  """
  @spec equip(Schema.Item.t()) :: {:ok, Schema.Item.t()} | {:error, any()}
  def equip(%Schema.Item{metadata: meta} = item) do
    equip(item, List.first(meta.slot_names))
  end

  def equip(%Schema.Item{location: :inventory} = item, equip_slot) do
    update_item(item, %{equip_slot: equip_slot, inventory_slot: nil, location: :equipment})
  end

  @doc """
  Unequips an item, moving it back to inventory.

  Finds an available inventory slot and updates the item location.

  ## Examples

      iex> unequip(item)
      {:ok, %Schema.Item{location: :inventory, ...}}

      iex> unequip(already_unequipped_item)
      {:error, :item_not_equipped}
  """
  @spec unequip(Schema.Item.t()) :: {:ok, Schema.Item.t()} | {:error, atom()}
  def unequip(%Schema.Item{} = item) do
    with slot <- find_first_available_slot(item.character_id, item.inventory_tab),
         {:ok, item} <-
           update_item(item, %{equip_slot: :NONE, inventory_slot: slot, location: :inventory}) do
      {:ok, item}
    else
      %Schema.Item{location: :inventory} ->
        {:error, :item_not_equipped}

      nil ->
        {:error, :item_not_found}
    end
  end

  @doc """
  Validates if a given slot name is a valid equipment slot.

  ## Examples

      iex> valid_slot?("HD")
      true

      iex> valid_slot?("invalid")
      false
  """
  @spec valid_slot?(String.t()) :: boolean()
  def valid_slot?(slot_name) do
    slot_name = String.to_existing_atom(slot_name)
    !!Enums.EquipSlot.get_value(slot_name)
  rescue
    _ -> false
  end
end
