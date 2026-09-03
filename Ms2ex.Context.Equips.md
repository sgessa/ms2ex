# `Ms2ex.Context.Equips`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/context/equips.ex#L1)

Context module for equipment persistence.

Provides the item-level operations behind equip transitions: reading a
character's equipped items, moving items between inventory and equipment,
and validating equipment slots. The equip transition itself (conflicting
items, state refresh, notifications) is owned by the character process,
see `Ms2ex.Managers.Character.Equips`.

# `equip`

```elixir
@spec equip(Ms2ex.Schema.Item.t(), atom()) ::
  {:ok, Ms2ex.Schema.Item.t()} | {:error, any()}
```

Equips an item into the requested equipment slot.

## Examples

    iex> equip(item, :RH)
    {:ok, %Schema.Item{location: :equipment, ...}}

# `list`

```elixir
@spec list(Ms2ex.Schema.Character.t()) :: [Ms2ex.Schema.Item.t()]
```

Lists all equipped items for a given character.

The rows are returned without their metadata documents; callers fetch
metadata from the storage cache only when they need it, so cached copies
of the list stay lean.

## Examples

    iex> list(character)
    [%Schema.Item{location: :equipment, ...}, ...]

# `unequip`

```elixir
@spec unequip(Ms2ex.Schema.Item.t(), integer() | nil) ::
  {:ok, Ms2ex.Schema.Item.t()}
  | {:discard, Ms2ex.Schema.Item.t()}
  | {:error, atom()}
```

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
