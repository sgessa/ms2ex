# `Ms2ex.Context.Items`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/context/items.ex#L1)

# `accessory?`

# `armor?`

# `bind_if_needed`

```elixir
@spec bind_if_needed(Ms2ex.Schema.Item.t(), :loot | :equip) :: Ms2ex.Schema.Item.t()
```

Binds an item to a character when its transfer type requires it and the
bind flag is set. Used before an INSERT (pickup), so the resulting struct
carries the bind; the equip path merges the changeset form directly.

# `drop_item`

```elixir
@spec drop_item(integer(), integer(), integer()) :: Ms2ex.Schema.Item.t() | nil
```

Builds a field-drop item from a drop table entry. Rolls rarity from the
caller when present; a non-positive rarity falls back to the item's
constant option, else rank 1. Returns `nil` when the item has no metadata.

# `havi_fruit`

# `havi_fruit?`

# `init`

```elixir
@spec init(integer(), map()) :: Ms2ex.Schema.Item.t()
```

# `load_metadata`

```elixir
@spec load_metadata(Ms2ex.Schema.Item.t()) :: Ms2ex.Schema.Item.t()
```

# `merets`

# `merets?`

# `mesos`

# `mesos?`

# `rue`

# `rue?`

# `set_level`

```elixir
@spec set_level(Ms2ex.Schema.Item.t()) :: Ms2ex.Schema.Item.t()
```

# `set_stats`

```elixir
@spec set_stats(Ms2ex.Schema.Item.t()) :: Ms2ex.Schema.Item.t()
```

# `sp`

# `sp?`

# `stamina`

# `stamina?`

# `valor_token`

# `valor_token?`

# `weapon?`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
