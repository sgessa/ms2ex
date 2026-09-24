# `Ms2ex.Context.HotBars`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/context/hot_bars.ex#L1)

Context module for hot bar persistence.

Hot bar rows live in the character-config manager's memory while a
character is online; this module loads them once and persists updates,
returning the updated rows for the manager's state.

# `list`

```elixir
@spec list(Ms2ex.Schema.Character.t()) :: [Ms2ex.Schema.HotBar.t()]
```

Lists all hot bars for a given character, ordered by ID.

## Examples

    iex> list(character)
    [%Schema.HotBar{}, %Schema.HotBar{}, ...]

# `set_active`

```elixir
@spec set_active(Ms2ex.Schema.HotBar.t(), boolean()) ::
  {:ok, Ms2ex.Schema.HotBar.t()} | {:error, Ecto.Changeset.t()}
```

Persists a bar's active flag and returns the updated row.

# `update_quick_slots`

```elixir
@spec update_quick_slots(Ms2ex.Schema.HotBar.t(), [Ms2ex.Types.QuickSlot.t()]) ::
  {:ok, Ms2ex.Schema.HotBar.t()} | {:error, Ecto.Changeset.t()}
```

Persists a bar's quick slots and returns the updated row: the manager's
state always carries what the database has.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
