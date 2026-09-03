# `Ms2ex.Managers.Quest.Rewards`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/managers/quest/rewards.ex#L1)

Quest reward helpers.

Reward delivery is split so callers can make quest completion and item
grants atomic:

  * `prepare/2` resolves and filters a reward document into grantable items
    (no writes)
  * `grant_items/2` performs the inventory writes; call it inside the
    caller's transaction so a failure rolls back the quest state change
  * `deliver/3` fires the post-commit effects (experience, currency
    updates and inventory packets)

# `deliver`

Post-commit delivery: experience through the character manager (it owns the
live exp/level state), currency wallet updates, and the inventory packets
for the granted items.

# `grant_items`

Inserts the prepared items into the character's inventory. Must run inside
a `Repo.transaction` so a failing grant rolls back the surrounding quest
state change. Returns `{:ok, inventory results}` for post-commit delivery.

# `prepare`

Resolves a reward document into grantable items: zero-filled entries and
items without projected metadata are dropped, job-gated items are matched
against the character's job. Performs no writes.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
