# `Ms2ex.Context.ItemStats`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/context/item_stats.ex#L1)

Aggregates the stat bonuses granted by equipped items and applies them to a
character's stats.

Each item's constant and static option stats are rolled through the
`calcItemValues` Lua script, then summed over every equipped item and added
to the character's current and maximum stat values.

# `apply`

Rebuilds a character's stats from the persisted base plus the bonuses of
every equipped item. The base is reloaded so repeated applications never
stack.

# `apply_stats`

Adds a map of stat bonuses to a character's current and maximum stats.

# `bonuses`

Stat bonuses granted by a single item: its constant plus static value stats.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
