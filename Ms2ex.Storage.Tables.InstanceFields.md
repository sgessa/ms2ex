# `Ms2ex.Storage.Tables.InstanceFields`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/storage/table/instance_fields.ex#L1)

Instance-field table: maps that are instanced rather than shared.
`solo` maps (tutorials, quest instances) allocate a private field per
entry; `channel_scale` maps share one field per channel. Maps absent
from the table are ordinary shared fields.

# `get`

```elixir
@spec get(integer()) :: map() | nil
```

Instance doc for a map (`:type`, `:instance_id`, `:pool_count`,
  `:max_count`, `:save_field`, `:npc_stat_factor_id`), or nil when the
  map is not instanced.

# `instanced?`

```elixir
@spec instanced?(integer()) :: boolean()
```

Whether the map is instanced at all (any instance type).

# `solo?`

```elixir
@spec solo?(integer()) :: boolean()
```

Whether the map allocates a private field instance per entry.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
