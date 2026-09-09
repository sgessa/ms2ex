# `Ms2ex.Managers.Quest.Conditions`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/managers/quest/conditions.ex#L1)

Quest condition helpers.

A quest in the manager state carries only its persisted condition
counters (`%{index => counter}`); the condition documents — type, value,
codes, target — live in the quest's storage metadata and are resolved
from ETS as each event is matched.

Progress matching follows the metadata layout: `codes` carry the event id
the condition is gated on (npc id, item id, skill id, map id, ...), while
`target` optionally carries a minimum-value gate the pushed value must
reach for the progress to count.

# `all_met?`

# `metadata_matches?`

Whether one condition document accepts the pushed event: the code
parameter must satisfy the condition's code gate (string codes match the
pushed string, integer codes the pushed long) and the pushed value its
target gate. Shared with the achievement conditions, which follow the
same metadata layout.

# `update`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
