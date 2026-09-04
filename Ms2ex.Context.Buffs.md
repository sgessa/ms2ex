# `Ms2ex.Context.Buffs`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/context/buffs.ex#L1)

Buffs that outlive the field they were cast in.

Effects whose metadata does not clear them on logout are stored with an
absolute expiry, so purchased or long-running effects survive map changes,
channel switches and relogs. Expiry is wall-clock because the tick base
they run on is per-VM and resets with the server.

# `stored`

```elixir
@type stored() :: %{
  effect_id: integer(),
  effect_level: integer(),
  stacks: integer(),
  remaining_ms: integer()
}
```

# `clear`

```elixir
@spec clear(integer()) :: :ok
```

Drops every stored buff for a character.

# `load`

```elixir
@spec load(integer()) :: [stored()]
```

Stored buffs with their remaining duration in milliseconds; expired rows are
skipped.

# `persist?`

```elixir
@spec persist?(integer(), integer()) :: boolean()
```

Whether an effect should be carried across sessions. Mirrors the reference's
`RemoveOnLogout` check.

# `save`

```elixir
@spec save(integer(), [map()]) :: :ok
```

Replaces the character's stored buffs with the ones still running on the
field they are leaving.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
