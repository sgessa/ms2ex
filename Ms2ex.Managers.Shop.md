# `Ms2ex.Managers.Shop`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/managers/shop.ex#L1)

Per-character vendor shop state: the open shop window, its instanced stock
for limited-stock shops, and the session's buy-back list.

Unlimited stock is rebuilt from metadata on every open. Shops with a
restock policy (`enable_reset`) keep their rolled stock and per-item
purchase counters until the restock window passes; that state persists per
owner (account or character, per the shop's policy) through
`Ms2ex.Context.Shops`.

# `buy`

Buys `quantity` of a stock entry of the open shop.

# `call`

# `cast`

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `clear_active_shop`

# `daily_reset`

Zeroes the restock counters of day-interval shop data.

# `instant_restock`

Pays to restock the open limited-stock shop immediately.

# `load`

Opens the shop window of an npc (the npc id titles the window).

# `purchase_buy_back`

Buys back a previously sold item.

# `refresh`

Re-rolls the open limited-stock shop (free, on scheduled restocks).

# `sell`

Sells `quantity` of an inventory item to the open shop.

# `start`

# `stop`

# `weekly_reset`

Zeroes the restock counters of week-interval shop data.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
