# `Ms2ex.Managers.Inventory`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/managers/inventory.ex#L1)

# `add_item`

```elixir
@spec add_item(Ms2ex.Schema.Character.t(), Ms2ex.Schema.Item.t()) ::
  {:ok,
   {:create, Ms2ex.Schema.Item.t()}
   | {:update, Ms2ex.Schema.Item.t()}
   | {:update_and_create, {Ms2ex.Schema.Item.t(), integer()},
      Ms2ex.Schema.Item.t()}}
```

Adds an item, merging onto existing stacks when stackable. Acquisition
flows notify the quest manager themselves (see
`Ms2ex.Managers.Quest.notify_item_acquired/2`).

# `alive?`

# `all`

Lists every item of a character, equipped and carried.

# `bind`

```elixir
@spec bind(Ms2ex.Schema.Item.t()) :: Ms2ex.Schema.Item.t()
```

Placeholder bind marker.

# `call`

# `cast`

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `consume`

```elixir
@spec consume(Ms2ex.Schema.Item.t(), integer()) ::
  {:update, Ms2ex.Schema.Item.t()}
  | {:delete, Ms2ex.Schema.Item.t()}
  | {:error, :not_found}
```

Consumes an amount of an item, deleting it when emptied.

# `consume_item_amount`

```elixir
@spec consume_item_amount(Ms2ex.Schema.Character.t(), integer(), integer()) ::
  {:ok, update: Ms2ex.Schema.Item.t(), delete: Ms2ex.Schema.Item.t()}
  | {:error, :insufficient_amount}
```

Consumes an amount across the character's carry stacks; returns
`{:error, :insufficient_amount}` when the stacks cannot cover it.

# `consume_item_amounts`

```elixir
@spec consume_item_amounts(Ms2ex.Schema.Character.t(), [map()]) ::
  {:ok, update: Ms2ex.Schema.Item.t(), delete: Ms2ex.Schema.Item.t()}
```

Consumes each `%{item_id, amount}` pair from the carry stacks. Pairs the
inventory cannot cover are skipped so callers can keep processing (the
completion counter no longer matches the live inventory in that case).

# `delete`

```elixir
@spec delete(Ms2ex.Schema.Item.t()) ::
  {:delete, Ms2ex.Schema.Item.t()} | {:error, any()}
```

Deletes an item.

# `equip`

```elixir
@spec equip(Ms2ex.Schema.Item.t(), atom()) ::
  {:ok, Ms2ex.Schema.Item.t()} | {:error, any()}
```

Equips an item into the requested slot, binding it first when its
metadata marks it bind-on-equip.

# `expand_tab`

```elixir
@spec expand_tab(Ms2ex.Schema.Character.t(), atom()) :: Ms2ex.Schema.InventoryTab.t()
```

Expands a tab by six slots.

# `expired?`

```elixir
@spec expired?(Ms2ex.Schema.Item.t()) :: boolean()
```

Checks whether an item's expiry date has passed.

# `find_first_available_slot`

```elixir
@spec find_first_available_slot(integer(), atom()) ::
  integer() | {:error, :full_inventory}
```

Finds the first free slot of a tab.

# `free_slot_count`

```elixir
@spec free_slot_count(integer(), atom()) :: non_neg_integer()
```

Counts the free slots of a tab.

# `get`

```elixir
@spec get(Ms2ex.Schema.Character.t(), integer()) :: Ms2ex.Schema.Item.t() | nil
```

Gets an item by uid.

# `list_equips`

Lists a character's equipped items.

# `list_items`

Lists a character's carried items, sorted by slot.

# `list_tab_items`

Lists a character's carried items in a tab, sorted by slot.

# `list_tabs`

Lists a character's inventory tab rows.

# `move_to_inventory`

```elixir
@spec move_to_inventory(Ms2ex.Schema.Item.t(), integer() | nil) ::
  {:ok, Ms2ex.Schema.Item.t()}
  | {:error, :full_inventory}
  | {:error, :not_found}
```

Moves an equipped item back to the inventory. Prefers `preferred_slot`
while it is free, else the first open slot in the tab; the item's equip
slot is cleared.

# `sort_tab`

```elixir
@spec sort_tab(Ms2ex.Schema.Character.t(), atom()) ::
  {:ok, [Ms2ex.Schema.Item.t()]} | {:error, any()}
```

Sorts a tab's carried items by item id.

# `start`

# `stop`

# `swap`

```elixir
@spec swap(Ms2ex.Schema.Item.t(), integer()) :: {:ok, integer()} | {:error, any()}
```

Swaps an item into a slot, displacing whatever occupies it.

# `update_item`

```elixir
@spec update_item(Ms2ex.Schema.Item.t() | Ecto.Changeset.t(), map()) ::
  {:ok, Ms2ex.Schema.Item.t()} | {:error, any()}
```

Updates an item's fields, writing through.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
