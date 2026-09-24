# `Ms2ex.Managers.CharacterConfig`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/managers/character_config.ex#L1)

# `bump_instant_revive_count`

```elixir
@spec bump_instant_revive_count(integer()) :: :ok | :error
```

Counts one instant revive against the daily allowance and persists it.

# `call`

# `cast`

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `fresh?`

```elixir
@spec fresh?(integer()) :: boolean() | :error
```

True while no quick slot of any bar holds a skill or item.

# `guide_records`

```elixir
@spec guide_records(integer()) :: map() | :error
```

Returns the character's guide-popup progress, keyed by guide id.

# `instant_revive_count`

```elixir
@spec instant_revive_count(integer()) :: integer()
```

Returns how many daily instant revives were used.

# `key_binds`

```elixir
@spec key_binds(integer()) :: map() | :error
```

Returns the character's saved key binds, keyed by key code.

# `list`

```elixir
@spec list(integer()) :: [Ms2ex.Schema.HotBar.t()] | :error
```

Lists the character's hot bars, in saved order.

# `merge_guide_records`

```elixir
@spec merge_guide_records(integer(), map()) :: :ok | :error
```

Merges client-reported guide steps into the saved progress and persists
the row.

# `merge_key_binds`

```elixir
@spec merge_key_binds(integer(), map()) :: :ok | :error
```

Merges client-sent key binds into the saved table (each entry upserted by
key code) and persists the row.

# `move_quick_slot`

```elixir
@spec move_quick_slot(integer(), integer(), Ms2ex.Types.QuickSlot.t(), integer()) ::
  :ok | :error
```

Moves a quick slot to a target position of the given hot bar and
persists the bar.

# `remove_quick_slot`

```elixir
@spec remove_quick_slot(integer(), integer(), integer(), integer()) :: :ok | :error
```

Removes the quick slot matching the given skill and item uid from the
given hot bar and persists the bar.

# `reset_daily`

```elixir
@spec reset_daily(integer()) :: :ok
```

Drops the cached daily instant-revive allowance after the daily reset
bulk-cleared it in the database.

# `set_active_bar`

```elixir
@spec set_active_bar(integer(), integer()) :: :ok | :error
```

Activates the hot bar at the given index (the client's active-bar switch)
and persists the flag flip.

# `start`

# `stop`

# `update_hotbar_skills`

```elixir
@spec update_hotbar_skills(Ms2ex.Schema.Character.t()) :: :ok | :error
```

Syncs the bars with the character's learned active skills: pure-skill
slots whose skill is no longer learned are cleared from every bar, and
learned actives missing from the active bar are placed in the next free
slot. Changed bars are persisted.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
