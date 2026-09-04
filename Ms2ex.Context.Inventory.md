# `Ms2ex.Context.Inventory`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/context/inventory.ex#L1)

Item persistence helpers.

Reads load the rows a manager needs to build its state, and writes
persist the mutations a manager has already applied to memory. All the
gameplay flows go through `Ms2ex.Managers.Inventory`; this module is its
database layer. The one flow that runs before any session exists —
character creation — inserts its starting outfit here directly.

# `assign_slot`

```elixir
@spec assign_slot(integer(), integer() | nil) :: :ok
```

Writes an item's inventory slot.

# `clear_slots`

```elixir
@spec clear_slots([integer()]) :: :ok
```

Clears the inventory slot of the given items (making them sortable).

# `delete_item`

```elixir
@spec delete_item(Ms2ex.Schema.Item.t()) ::
  {:ok, Ms2ex.Schema.Item.t()} | {:error, Ecto.Changeset.t()}
```

Deletes an item row.

# `delete_items`

```elixir
@spec delete_items([integer()]) :: :ok
```

Deletes item rows by id.

# `expand_tab`

```elixir
@spec expand_tab(integer(), integer()) :: :ok
```

Adds extra slots to an inventory tab row.

# `insert_item`

```elixir
@spec insert_item(integer(), Ms2ex.Schema.Item.t() | map()) ::
  {:ok, Ms2ex.Schema.Item.t()} | {:error, Ecto.Changeset.t()}
```

Inserts a new item row. The attributes must already carry the inventory
tab, slot and rarity; the tab is derived from the item's metadata when
not given.

# `list_equipped`

```elixir
@spec list_equipped(integer()) :: [Ms2ex.Schema.Item.t()]
```

Lists a character's equipped item rows.

# `list_items`

```elixir
@spec list_items(integer()) :: [Ms2ex.Schema.Item.t()]
```

Lists every item row of a character (equipped and carried).

# `list_tabs`

```elixir
@spec list_tabs(integer()) :: [Ms2ex.Schema.InventoryTab.t()]
```

Lists a character's inventory tab rows.

# `set_amount`

```elixir
@spec set_amount(integer(), integer()) :: :ok
```

Overwrites an item's amount.

# `update_amount`

```elixir
@spec update_amount(integer(), integer()) :: :ok
```

Adds a delta to an item's amount.

# `update_item`

```elixir
@spec update_item(Ms2ex.Schema.Item.t() | Ecto.Changeset.t(), map()) ::
  {:ok, Ms2ex.Schema.Item.t()} | {:error, Ecto.Changeset.t()}
```

Updates an item row from a struct or changeset plus attributes.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
