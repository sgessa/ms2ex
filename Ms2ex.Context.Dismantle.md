# `Ms2ex.Context.Dismantle`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/context/dismantle.ex#L1)

Handles the item dismantling functionality.

This module provides operations for managing the dismantling inventory,
including adding/removing items and calculating the rewards that will
be obtained from dismantling those items.

The dismantling process in MS2EX works by:
1. Adding items to a temporary dismantling inventory
2. Calculating expected rewards based on item metadata
3. When confirmed, removing items from player inventory and granting rewards

# `add`

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

# `append`

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

# `max_slots`

Returns the maximum number of slots available in the dismantling inventory.

## Returns

  * Integer representing the maximum number of slots (100)

# `remove`

Removes an item from the specified slot in the dismantle inventory.

## Parameters

  * `inventory` - The current dismantle inventory
  * `slot` - The slot number to remove the item from

## Returns

  * Updated dismantle inventory with the specified slot removed

# `update_rewards`

Calculates the rewards that would be obtained from dismantling the items
currently in the dismantle inventory.

This function:
1. Iterates through all items in the dismantle inventory
2. Retrieves the dismantle rewards metadata for each item
3. Calculates the total rewards based on the quantity of each item
4. Updates the inventory with the calculated rewards

## Parameters

  * `inventory` - The current dismantle inventory
  * `item_resolver` - Resolves an item uid to the character's item (the
    flow reads it from the character's inventory manager)

## Returns

  * Updated dismantle inventory with the `rewards` field populated

---

*Consult [api-reference.md](api-reference.md) for complete listing*
