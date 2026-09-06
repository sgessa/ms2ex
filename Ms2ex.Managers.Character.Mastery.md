# `Ms2ex.Managers.Character.Mastery`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/managers/character/mastery.ex#L1)

Life skill (mastery) state owned by the character process: the mastery
value per type, how often each gathering recipe was harvested and which
grade reward boxes were claimed.

Everything is read from and written to memory; the row is only persisted
on the periodic flush and on disconnect, so a gathering spree does not
write one UPDATE per node.

# `add`

Adds mastery. The value never decreases and is capped at the type's
maximum; the client is told the new value and grade changes feed the
matching trophy/quest conditions.

# `all`

Mastery values of a character, keyed by mastery type.

# `claim`

# `claimed?`

# `count_gather`

Bumps the harvest counter of a gathering recipe.

# `flush`

Persists the mastery state when it changed since the last flush.

# `gathering_counts`

Gathering counts of a character, keyed by recipe id.

# `grade`

Mastery grade (level) a type has reached.

# `rewards_claimed`

Claimed mastery grade reward boxes, keyed by reward box id.

# `value`

Mastery value of a single type.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
