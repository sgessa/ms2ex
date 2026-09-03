# `Ms2ex.Context.Inventory`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/context/inventory.ex#L1)

Context module for inventory-related operations.

This module provides functions for managing character inventories,
including adding, removing, updating, and organizing items.

# `add_item`

```elixir
@spec add_item(Ms2ex.Schema.Character.t(), Ms2ex.Schema.Item.t()) ::
  {:ok,
   {:create, Ms2ex.Schema.Item.t()}
   | {:update, Ms2ex.Schema.Item.t()}
   | {:update_and_create, {Ms2ex.Schema.Item.t(), integer()},
      Ms2ex.Schema.Item.t()}}
```

Adds an item to a character's inventory.

Handles stackable items by finding existing stacks that can be increased.

## Examples

    iex> add_item(character, item)
    {:ok, {:create, %Schema.Item{}}}

# `all`

```elixir
@spec all(Ms2ex.Schema.Character.t()) :: [Ms2ex.Schema.Item.t()]
```

Gets all items belonging to a character.

## Examples

    iex> all(character)
    [%Schema.Item{}, %Schema.Item{}, ...]

# `bind`

```elixir
@spec bind(Ms2ex.Schema.Item.t()) :: Ms2ex.Schema.Item.t()
```

Binds an item to a character (placeholder).

## Examples

    iex> bind(item)
    %Schema.Item{}

# `consume`

```elixir
@spec consume(Ms2ex.Schema.Item.t(), integer()) ::
  {:update, Ms2ex.Schema.Item.t()} | {:delete, Ms2ex.Schema.Item.t()}
```

Consumes a given amount of an item.

Reduces the item amount by the consumed amount, or deletes the item if amount would be zero.

## Examples

    iex> consume(item, 2)
    {:update, %Schema.Item{amount: 3}}

    iex> consume(item, 5)
    {:delete, %Schema.Item{}}

# `consume_item_amount`

```elixir
@spec consume_item_amount(Ms2ex.Schema.Character.t(), integer(), integer()) ::
  {:ok, update: Ms2ex.Schema.Item.t(), delete: Ms2ex.Schema.Item.t()}
  | {:error, :insufficient_amount}
```

Consumes an amount of an item across the character's carry stacks,
deleting stacks emptied by the consumption. Must run inside the caller's
transaction when atomicity matters. Returns per-stack results for
inventory packets; `{:error, :insufficient_amount}` when the character
holds fewer than the requested amount.

# `consume_item_amounts`

```elixir
@spec consume_item_amounts(Ms2ex.Schema.Character.t(), [map()]) ::
  {:ok, update: Ms2ex.Schema.Item.t(), delete: Ms2ex.Schema.Item.t()}
```

Consumes each `%{item_id, amount}` pair from the character's carry stacks,
loading every needed stack with a single query and deleting stacks emptied
by the consumption. Pairs the inventory cannot cover are skipped so callers
can keep processing (the completion counter no longer matches the live
inventory in that case).

# `delete`

```elixir
@spec delete(Ms2ex.Schema.Item.t()) ::
  {:delete, Ms2ex.Schema.Item.t()} | {:error, Ecto.Changeset.t()}
```

Deletes an item from the inventory.

## Examples

    iex> delete(item)
    {:delete, %Schema.Item{}}

# `expand_tab`

```elixir
@spec expand_tab(Ms2ex.Schema.Character.t(), atom()) :: Ms2ex.Schema.InventoryTab.t()
```

Expands an inventory tab by adding additional slots.

## Examples

    iex> expand_tab(character, :outfit)
    %Schema.InventoryTab{slots: 36}

# `expired?`

```elixir
@spec expired?(Ms2ex.Schema.Item.t()) :: boolean()
```

Checks if an item has expired.

## Examples

    iex> expired?(item)
    true

# `find_first_available_slot`

```elixir
@spec find_first_available_slot(integer(), atom()) ::
  integer() | {:error, :full_inventory}
```

Finds the first available inventory slot in a given tab.

## Examples

    iex> find_first_available_slot(1, :outfit)
    5

# `find_stack`

```elixir
@spec find_stack(Ms2ex.Schema.Character.t(), Ms2ex.Schema.Item.t()) ::
  Ms2ex.Schema.Item.t() | nil
```

Finds an existing stack of the same item that isn't at its stack limit.

## Examples

    iex> find_stack(character, item)
    %Schema.Item{amount: 5}

# `get`

```elixir
@spec get(Ms2ex.Schema.Character.t(), integer()) :: Ms2ex.Schema.Item.t() | nil
```

Gets an item by ID for a character.

## Examples

    iex> get(character, 123)
    %Schema.Item{}

# `get_by`

```elixir
@spec get_by(map()) :: Ms2ex.Schema.Item.t() | nil
```

Gets an item from the inventory by the given attributes.

## Examples

    iex> get_by(%{character_id: 1, id: 123})
    %Schema.Item{}

    iex> get_by(%{character_id: 999, id: 456})
    nil

# `item_in_slot`

```elixir
@spec item_in_slot(integer(), atom(), integer()) :: Ms2ex.Schema.Item.t() | nil
```

Gets the item in a specific inventory slot.

## Examples

    iex> item_in_slot(1, :outfit, 5)
    %Schema.Item{inventory_slot: 5}

# `list_items`

```elixir
@spec list_items(Ms2ex.Schema.Character.t()) :: [Ms2ex.Schema.Item.t()]
```

Lists all items in a character's inventory (excluding equipped items).

Returns items sorted by inventory slot.

## Examples

    iex> list_items(character)
    [%Schema.Item{location: :inventory}, ...]

# `list_tab_items`

```elixir
@spec list_tab_items(integer(), atom()) :: [Ms2ex.Schema.Item.t()]
```

Lists items in a specific inventory tab.

## Examples

    iex> list_tab_items(character_id, :outfit)
    [%Schema.Item{inventory_tab: :outfit}, ...]

# `list_tabs`

```elixir
@spec list_tabs(Ms2ex.Schema.Character.t()) :: [Ms2ex.Schema.InventoryTab.t()]
```

Lists all inventory tabs for a character.

## Examples

    iex> list_tabs(character)
    [%Schema.InventoryTab{tab: :outfit}, ...]

# `sort_tab`

```elixir
@spec sort_tab(Ms2ex.Schema.Character.t(), atom()) ::
  {:ok, [Ms2ex.Schema.Item.t()]} | {:error, any()}
```

Sorts items in a tab by item ID.

## Examples

    iex> sort_tab(character, :outfit)
    {:ok, [%Schema.Item{}, ...]}

# `swap`

```elixir
@spec swap(Ms2ex.Schema.Item.t(), integer()) :: {:ok, integer()} | {:error, any()}
```

Swaps an item to a new slot, handling any item that might already be in that slot.

## Examples

    iex> swap(item, 10)
    {:ok, 0}

# `update_item`

```elixir
@spec update_item(Ms2ex.Schema.Item.t() | Ecto.Changeset.t(), map()) ::
  {:ok, Ms2ex.Schema.Item.t()} | {:error, Ecto.Changeset.t()}
```

Updates an item with the given attributes.

## Examples

    iex> update_item(item, %{amount: 5})
    {:ok, %Schema.Item{amount: 5}}

---

*Consult [api-reference.md](api-reference.md) for complete listing*
