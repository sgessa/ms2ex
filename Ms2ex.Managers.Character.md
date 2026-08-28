# `Ms2ex.Managers.Character`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/managers/character.ex#L1)

# `call`

# `cast`

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `get_skill_cooldowns`

```elixir
@spec get_skill_cooldowns(integer()) :: {:ok, [map()]} | :error
```

# `init`

# `lookup`

```elixir
@spec lookup(integer()) :: {:ok, Ms2ex.Schema.Character.t()} | :error
```

# `lookup_by_name`

```elixir
@spec lookup_by_name(String.t()) :: {:ok, Ms2ex.Schema.Character.t()} | :error
```

# `monitor`

# `save_skill_cooldown`

```elixir
@spec save_skill_cooldown(Ms2ex.Schema.Character.t(), map()) :: :ok | :error
```

# `set_level`

```elixir
@spec set_level(Ms2ex.Schema.Character.t(), integer()) ::
  {:ok, Ms2ex.Schema.Character.t()} | :error
```

# `set_skill_cooldown`

```elixir
@spec set_skill_cooldown(Ms2ex.Schema.Character.t(), integer(), integer(), integer()) ::
  {:ok, map()} | :error
```

# `start`

# `update`

```elixir
@spec update(Ms2ex.Schema.Character.t()) :: :ok | :error
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
