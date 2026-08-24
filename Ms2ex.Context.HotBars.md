# `Ms2ex.Context.HotBars`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/context/hot_bars.ex#L1)

Context module for hot bar-related operations.

This module provides functions for managing
character hot bars and quick slots.

# `get_by`

```elixir
@spec get_by(map()) :: Ms2ex.Schema.HotBar.t() | nil
```

Gets a hot bar by the given attributes.

## Examples

    iex> get_by(%{character_id: 1, id: 1})
    %Schema.HotBar{}

    iex> get_by(%{character_id: 999})
    nil

# `list`

```elixir
@spec list(Ms2ex.Schema.Character.t()) :: [Ms2ex.Schema.HotBar.t()]
```

Lists all hot bars for a given character.

Returns hot bars ordered by ID.

## Examples

    iex> list(character)
    [%Schema.HotBar{}, %Schema.HotBar{}, ...]

# `move_quick_slot`

```elixir
@spec move_quick_slot(Ms2ex.Schema.HotBar.t(), Ms2ex.Types.QuickSlot.t(), integer()) ::
  {:ok, Ms2ex.Schema.HotBar.t()} | {:error, Ecto.Changeset.t()} | :error
```

Moves a quick slot to a new target position in a hot bar.

If there's already a quick slot at the target position, the slots are swapped.
If the target position is invalid, returns an error.

## Examples

    iex> move_quick_slot(hot_bar, quick_slot, 3)
    {:ok, %Schema.HotBar{}}

    iex> move_quick_slot(hot_bar, quick_slot, -1)
    :error

# `remove_quick_slot`

```elixir
@spec remove_quick_slot(Ms2ex.Schema.HotBar.t(), integer(), String.t() | nil) ::
  {:ok, Ms2ex.Schema.HotBar.t()} | {:error, Ecto.Changeset.t()} | :error
```

Removes a quick slot from a hot bar.

Finds the quick slot by skill ID and item UID and replaces it with an empty slot.

## Parameters

  * `hot_bar` - The hot bar to modify
  * `skill_id` - The skill ID to find
  * `item_uid` - The item UID to find

## Examples

    iex> remove_quick_slot(hot_bar, 10500, "item123")
    {:ok, %Schema.HotBar{}}

    iex> remove_quick_slot(hot_bar, 99999, "nonexistent")
    :error

---

*Consult [api-reference.md](api-reference.md) for complete listing*
