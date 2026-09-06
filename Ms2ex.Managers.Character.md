# `Ms2ex.Managers.Character`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/managers/character.ex#L1)

# `call`

# `cast`

# `check_death`

```elixir
@spec check_death(Ms2ex.Schema.Character.t()) :: Ms2ex.Schema.Character.t()
```

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `init`

# `lookup`

```elixir
@spec lookup(integer()) :: {:ok, Ms2ex.Schema.Character.t()} | :error
```

# `lookup_by_name`

```elixir
@spec lookup_by_name(String.t()) :: {:ok, Ms2ex.Schema.Character.t()} | :error
```

# `online_ids`

```elixir
@spec online_ids() :: [integer()]
```

# `start`

# `update_state`

Merges runtime-only fields (cooldowns, buffs, regen, ...) from the manager
state back onto a (possibly stale) character struct. Pure: state in,
character out.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
