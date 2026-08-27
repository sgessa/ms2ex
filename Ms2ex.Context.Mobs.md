# `Ms2ex.Context.Mobs`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/context/mobs.ex#L1)

# `drop_corpse_rewards`

Rolls corpse loot from the mob's `dead_global_drop_box_ids` and locks it
to the player who struck the body. Drops on every corpse strike.

# `drop_hit_rewards`

Rolls the mob's on-hit drops from its `drop_info` metadata. Global hit
boxes drop unlocked loot; individual hit boxes are locked to the player
who dealt the hit.

# `drop_rewards`

Rolls the mob's death drops from its `drop_info` metadata.

Bosses drop shared global loot (unlocked) plus per-dealer individual
loot; regular mobs drop global and individual loot locked to the tagged
player. Mobs without drop metadata drop nothing. When `map_id` is given,
drop groups/items are gated on the map's type, continent and id.

# `reward_exp`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
