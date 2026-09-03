# `Ms2ex.Schema.Item`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/schema/item.ex#L1)

# `t`

```elixir
@type t() :: %Ms2ex.Schema.Item{
  __meta__: term(),
  amount: term(),
  appearance_flag: term(),
  can_repackage: term(),
  character: term(),
  character_id: term(),
  charges: term(),
  color: term(),
  data: term(),
  enchant_exp: term(),
  enchant_level: term(),
  equip_slot: term(),
  expires_at: term(),
  glamor_forges_left: term(),
  id: term(),
  inserted_at: term(),
  inventory_slot: term(),
  inventory_tab: term(),
  is_bound: term(),
  is_locked: term(),
  item_id: term(),
  level: term(),
  limit_break_level: term(),
  location: term(),
  lock_character_id: term(),
  metadata: term(),
  mob_drop?: term(),
  object_id: term(),
  position: term(),
  rarity: term(),
  remaining_trades: term(),
  source_object_id: term(),
  stats: term(),
  target_object_id: term(),
  times_attr_changed: term(),
  transfer_flags: term(),
  ugc: term(),
  unlocks_at: term(),
  updated_at: term()
}
```

# `bind_if_needed`

```elixir
@spec bind_if_needed(t(), :loot | :equip) :: t() | Ecto.Changeset.t()
```

Returns a changeset carrying the bind change (or the item unchanged) when
the transfer type requires binding. Callers merge the changeset into the
persist; the change is only produced when the item is not already bound.

# `changeset`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
