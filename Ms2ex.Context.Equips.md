# `Ms2ex.Context.Equips`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/context/equips.ex#L1)

Context module for equipment-related operations.

This module provides functions for listing, equipping, and unequipping items,
as well as validating equipment slots.

# `equip`

```elixir
@spec equip(Ms2ex.Schema.Item.t()) :: {:ok, Ms2ex.Schema.Item.t()} | {:error, any()}
```

Equips an item using its first available slot.

## Examples

    iex> equip(item)
    {:ok, %Schema.Item{location: :equipment, ...}}

# `equip`

# `find_equipped_in_slots`

```elixir
@spec find_equipped_in_slots([Ms2ex.Schema.Item.t()], [atom()], atom(), atom() | nil) ::
  [
    Ms2ex.Schema.Item.t()
  ]
```

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

# `list`

```elixir
@spec list(Ms2ex.Schema.Character.t()) :: [Ms2ex.Schema.Item.t()]
```

Lists all equipped items for a given character.

Returns a list of items with their metadata loaded.

## Examples

    iex> list(character)
    [%Schema.Item{location: :equipment, ...}, ...]

# `unequip`

```elixir
@spec unequip(Ms2ex.Schema.Item.t()) ::
  {:ok, Ms2ex.Schema.Item.t()} | {:error, atom()}
```

Unequips an item, moving it back to inventory.

Finds an available inventory slot and updates the item location.

## Examples

    iex> unequip(item)
    {:ok, %Schema.Item{location: :inventory, ...}}

    iex> unequip(already_unequipped_item)
    {:error, :item_not_equipped}

# `valid_slot?`

```elixir
@spec valid_slot?(String.t()) :: boolean()
```

Validates if a given slot name is a valid equipment slot.

## Examples

    iex> valid_slot?("HD")
    true

    iex> valid_slot?("invalid")
    false

---

*Consult [api-reference.md](api-reference.md) for complete listing*
