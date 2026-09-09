# `Ms2ex.Managers.Field.Buff`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/managers/field/buff.ex#L1)

# `add_buff`

# `add_effect_buff`

# `add_effect_buff_for`

# `add_mob_buff`

# `modify_duration`

Shifts the remaining duration of an actor's effect, as interact objects do
when they extend or cut a buff short.

# `owner_has_buff?`

Whether an actor currently has the given effect active, regardless of who
cast it.

# `owner_has_buff_event?`

Whether an actor has an effect of the given event category active (the
auto-fish and auto-perform conveniences, safe riding, ...).

# `remove_buff`

# `remove_owner_buffs`

# `remove_owner_effect`

Removes a single effect from an actor, whoever cast it.

# `restore_buffs`

Re-applies the character's stored buffs for the remainder of their duration.

# `save_owner_buffs`

Stores the character's still-running buffs so they can be restored on the
next field they enter, including after a relog.

# `tick`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
