defmodule Ms2ex.Context.Dismantle do
  @moduledoc """
  Handles the item dismantling functionality.

  This module provides operations for managing the dismantling inventory,
  including adding/removing items and calculating the rewards that will
  be obtained from dismantling those items.

  The dismantling process in MS2EX works by:
  1. Adding items to a temporary dismantling inventory
  2. Calculating expected rewards based on item metadata
  3. When confirmed, removing items from player inventory and granting rewards
  """

  alias Ms2ex.Context

  @max_slots 100

  @doc """
  Returns the maximum number of slots available in the dismantling inventory.

  ## Returns

    * Integer representing the maximum number of slots (#{@max_slots})
  """
  def max_slots(), do: @max_slots

  @doc """
  Adds an item to the dismantle inventory.

  When a specific slot is requested:
  - If the slot is occupied, falls back to finding any available slot (append)
  - If the slot is available, places the item in that slot

  ## Parameters

    * `inventory` - The current dismantle inventory
    * `slot` - The requested slot number
    * `uid` - The unique identifier of the item to dismantle
    * `amount` - The quantity of the item to dismantle

  ## Returns

    * A tuple of `{slot_number, updated_inventory}` where:
      - `slot_number` is the slot where the item was placed
      - `updated_inventory` is the modified dismantle inventory
  """
  def add(%{slots: slots} = inventory, slot, uid, amount) when slot >= 0 do
    if Map.has_key?(slots, slot) do
      append(inventory, uid, amount)
    else
      slots = Map.put(slots, slot, {uid, amount})
      {slot, %{inventory | slots: slots}}
    end
  end

  def add(inventory, -1, uid, amount) do
    append(inventory, uid, amount)
  end

  @doc """
  Adds an item to the first available slot in the dismantle inventory.

  Searches for the first unoccupied slot from 0 to @max_slots and places
  the item there.

  ## Parameters

    * `inventory` - The current dismantle inventory
    * `uid` - The unique identifier of the item to dismantle
    * `amount` - The quantity of the item to dismantle

  ## Returns

    * A tuple of `{slot_number, updated_inventory}` where:
      - `slot_number` is the slot where the item was placed
      - `updated_inventory` is the modified dismantle inventory
  """
  def append(%{slots: slots} = inventory, uid, amount) do
    free_slot = Enum.find(0..@max_slots, &(!Map.has_key?(slots, &1)))
    slots = Map.put(slots, free_slot, {uid, amount})
    {free_slot, %{inventory | slots: slots}}
  end

  @doc """
  Removes an item from the specified slot in the dismantle inventory.

  ## Parameters

    * `inventory` - The current dismantle inventory
    * `slot` - The slot number to remove the item from

  ## Returns

    * Updated dismantle inventory with the specified slot removed
  """
  def remove(%{slots: slots} = inventory, slot) do
    slots = Map.delete(slots, slot)
    %{inventory | slots: slots}
  end

  @doc """
  Calculates the rewards that would be obtained from dismantling the items
  currently in the dismantle inventory.

  This function:
  1. Iterates through all items in the dismantle inventory
  2. Retrieves the dismantle rewards metadata for each item
  3. Calculates the total rewards based on the quantity of each item
  4. Updates the inventory with the calculated rewards

  ## Parameters

    * `character` - The character whose inventory contains the items
    * `inventory` - The current dismantle inventory

  ## Returns

    * Updated dismantle inventory with the `rewards` field populated
  """
  def update_rewards(character, inventory) do
    rewards =
      Enum.reduce(inventory.slots, %{}, fn {_slot, {item_uid, amount}}, total_rewards ->
        item = character |> Context.Inventory.get(item_uid) |> Context.Items.load_metadata()
        rewards = Map.get(item.metadata, :dismantle_rewards, [])
        sum_item_rewards(rewards, total_rewards, amount)
      end)

    %{inventory | rewards: rewards}
  end

  defp sum_item_rewards(rewards, total_rewards, amount) do
    Enum.reduce(rewards, total_rewards, fn reward, total_rewards ->
      if reward.item_id != 0 do
        total_amount = Map.get(total_rewards, reward.item_id, 0)
        total_amount = total_amount + reward.amount * amount
        Map.put(total_rewards, reward.item_id, total_amount)
      else
        total_rewards
      end
    end)
  end
end
