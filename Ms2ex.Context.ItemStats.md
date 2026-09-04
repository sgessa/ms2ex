# `Ms2ex.Context.ItemStats`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/context/item_stats.ex#L1)

Aggregates the stat bonuses granted by equipped items and learned passive
skills, then applies them to a character's stats.

Calculated item and passive effects are summed and added to the character's
base stat values.

# `apply`

Rebuilds a character's stats and returns the derived packet data. The
equipped items are passed in by the caller — contexts do not read manager
state.

# `apply_stats`

Adds a map of stat bonuses to a character's current and maximum stats.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
