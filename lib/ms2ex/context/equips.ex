defmodule Ms2ex.Context.Equips do
  @moduledoc """
  Context module for equipment persistence.

  Provides the item-level operations behind equip transitions: reading a
  character's equipped items, moving items between inventory and equipment,
  and validating equipment slots. The equip transition itself (conflicting
  items, state refresh, notifications) is owned by the character process,
  see `Ms2ex.Managers.Character.Equips`.
  """

  alias Ms2ex.Context
  alias Ms2ex.Schema
  alias Ms2ex.Repo
  alias Ms2ex.Enums

  import Ecto.Query, except: [update: 2]
  import Context.Inventory, only: [update_item: 2, find_first_available_slot: 2]

  # looks worn in these slots are discarded when unequipped rather than
  # returned to the inventory
  @discard_on_unequip_slots [:HR, :ER, :FA, :FD]

  @doc """
  Lists all equipped items for a given character.

  The rows are returned without their metadata documents; callers fetch
  metadata from the storage cache only when they need it, so cached copies
  of the list stay lean.

  ## Examples

      iex> list(character)
      [%Schema.Item{location: :equipment, ...}, ...]
  """
  @spec list(Schema.Character.t()) :: [Schema.Item.t()]
  def list(%Schema.Character{id: char_id}) do
    Schema.Item
    |> where([i], i.character_id == ^char_id and i.location == ^:equipment)
    |> Repo.all()
  end

  @doc """
  Equips an item into the requested equipment slot.

  ## Examples

      iex> equip(item, :RH)
      {:ok, %Schema.Item{location: :equipment, ...}}
  """
  @spec equip(Schema.Item.t(), atom()) :: {:ok, Schema.Item.t()} | {:error, any()}
  def equip(%Schema.Item{location: :inventory} = item, equip_slot) do
    item
    |> Schema.Item.bind_if_needed(:equip)
    |> update_item(%{equip_slot: equip_slot, inventory_slot: nil, location: :equipment})
  end

  @doc """
  Unequips an item, moving it back to the inventory.

  Prefers `preferred_slot` when it is free, else falls back to the first
  available slot in the tab. Items in cosmetic slots (hair, ears, face,
  face decal) are discarded instead: those looks cannot be worn again once
  removed.

  ## Examples

      iex> unequip(item)
      {:ok, %Schema.Item{location: :inventory, ...}}

      iex> unequip(hair_item)
      {:discard, %Schema.Item{}}

      iex> unequip(item)
      {:error, :full_inventory}
  """
  @spec unequip(Schema.Item.t(), integer() | nil) ::
          {:ok, Schema.Item.t()} | {:discard, Schema.Item.t()} | {:error, atom()}
  def unequip(%Schema.Item{} = item, preferred_slot \\ nil) do
    if item.equip_slot in @discard_on_unequip_slots do
      discard(item)
    else
      move_to_inventory(item, preferred_slot)
    end
  end

  defp discard(%Schema.Item{} = item) do
    case Context.Inventory.delete(item) do
      {:delete, item} -> {:discard, item}
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp move_to_inventory(item, preferred_slot) do
    case available_slot(item, preferred_slot) do
      {:ok, slot} ->
        update_item(item, %{equip_slot: :NONE, inventory_slot: slot, location: :inventory})

      error ->
        error
    end
  end

  # prefers the given slot while it is still free, else falls back to the
  # first open slot in the tab
  defp available_slot(item, preferred_slot) when is_integer(preferred_slot) do
    case Context.Inventory.item_in_slot(item.character_id, item.inventory_tab, preferred_slot) do
      nil -> {:ok, preferred_slot}
      _item -> available_slot(item, nil)
    end
  end

  defp available_slot(item, _preferred_slot) do
    case find_first_available_slot(item.character_id, item.inventory_tab) do
      slot when is_integer(slot) -> {:ok, slot}
      error -> error
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
