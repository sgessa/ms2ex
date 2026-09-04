# `Ms2ex.Context.Drops`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/context/drops.ex#L1)

Rolls items from the server drop tables (individual drop boxes and global
drop boxes), shared by mob loot and item boxes.

Individual boxes roll per character: groups gate on the character's
level, items are gender-filtered for smart-gender groups, gated on map,
and job-weighted when the group has a smart drop rate, before rolling
the weighted drop count. Global boxes roll per level with map
type/continent gates. A nil map id disables map gating entirely.

# `global_items`

```elixir
@spec global_items(integer(), integer(), integer() | map()) :: [Ms2ex.Schema.Item.t()]
```

Rolls a global drop box against the given level (the mob's level for mob
loot, the character's level for boxes).

# `individual_items`

```elixir
@spec individual_items(
  integer(),
  Ms2ex.Schema.Character.t(),
  integer() | map(),
  keyword()
) :: [
  Ms2ex.Schema.Item.t()
]
```

Rolls an individual drop box for a character. Options:

  * `:index` - selects the item at this ordinal within the resolved
    group, skipping requirement filters (select boxes; requires `:group`)
  * `:group` - restricts the roll to a single drop group

---

*Consult [api-reference.md](api-reference.md) for complete listing*
