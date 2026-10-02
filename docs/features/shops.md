# NPC shops (vendors)

Status: the full vendor loop is live — talking to a shop npc opens its
window, buying charges any currency, selling pays the item's table price and
stages a buy-back, and limited-stock shops roll and restock on their windows.
Guild-gated purchases and several exotic currencies are still open (see
gaps).

## Metadata

Three ingested sources feed vendors (see `../ms2ex-file-ingest`):

- `table:server.shop.xml` — one entry per shop id (`Storage.Tables.Shop`):
  window category/name/frame flags, `is_only_sell`, and the `restock` policy
  of limited-stock shops (`enable_reset`): `reset_type`
  (`Enums.ResetType`: default/day/week/month/unlimited), `currency_type`,
  `min_item_count`/`max_item_count` of the rolled stock, restock `price`,
  `account_wide` ownership. A fixed `restock_time` epoch on the shop wins
  over the computed interval boundary.
- `table:server.shopitem.xml` — stock entries per shop id
  (`Storage.Tables.ShopItems`), keyed by the entry's serial (`sn`, the id the
  client uses in buy requests): item id, rarity, `cost` (currency type +
  amount + optional sale amount), `sell_count` (stock limit, 0 = unlimited),
  `sell_unit` (amount per purchase), requirement blocks (achievement /
  guild trophy / championship / guild npc / alliance), `restricted_buy`
  window (start/end epoch, time-of-day ranges in seconds, day-of-week list)
  and the roll `probability` (out of 10000).
- `npc:<id>` docs carry `basic.shop_id` (0 when the npc has no shop). Items
  carry `limit.shop_sell` (whether vendors buy the item back) and
  `property.sell_prices`/`custom_sell_prices` (per-rarity vendor prices).

## Opening a shop

`GameHandlers.NpcTalk` assembles the talk-type flags from what the npc
offers — the shop counts as the *dialog* option, alongside quest and talk
script options; when more than one option exists and the npc has a select
script, the *select* flag turns the response into the choice menu (options
ordered quests, dialog, talk). The shop window packets are sent at talk time
for every vendor:

- npc with a select page as its only script (the common vendor greeting):
  the response carries the dialog flag with the select page's state and,
  for shop-kind npcs (`basic.kind` 1 or 11–19), no button — the client
  closes the greeting and reveals the shop window. In a choice menu, picking
  the dialog option answers with a bare talk continue that does the same.
- npc without any script: an empty dialog response (state/button 0) closes
  straight into the shop.

Closing the talk (`NpcTalk` command 0) clears the active shop.

Unlimited shops (`enable_reset == false`) rebuild their stock from metadata
on every open. Limited shops assemble an instanced shop (below).

## Packets

`Packets.Shop` (send opcode `SHOP`, recv opcode `SHOP`):

- `open` (0x0): npc id, then the shop block — id, restock deadline (epoch
  seconds), stock count, category, window flags, name; for reset shops a
  trailing restock block (currencies, price, multiplier flag, current
  `restock_count`, reset type, instant-restock/ownership flags).
- `load_items` (0x1): per entry — entry id, item id, cost block, rarity,
  stock count, purchased amount (× `sell_unit`), requirement fields, labels,
  restricted-buy window, then the full item serialization
  (`Packets.InventoryItem.put_item/3`).
- `update` (0x2): entry id + purchased amount after a limited purchase.
- `buy` (0x4): echo of item id, total amount, total price, rarity.
- `buy_back_item_count` (0x6) / `load_buy_back` (0x7) /
  `remove_buy_back` (0x8): the session's buy-back list (id, item, rarity,
  price, full item serialization).
- `instant_restock` (0x9): empty ack after a paid/free restock.
- `error` (0xF): `Enums.ShopError` value + two args (the second carries the
  missing payment item id).

Requests (`GameHandlers.Shop`): buy-back purchase (3), buy (4: entry id +
quantity), sell (5: item uid + quantity), instant restock (9, client echoes
the cost, ignored), refresh (10).

## Manager state and persistence

`Ms2ex.Managers.Shop` (process `shops:<character_id>`, started at login,
stopped on disconnect) owns:

- `active_shop` + the npc that opened it.
- `instanced_shops` — assembled limited-stock shops, session-scoped.
- `buy_back_items` — session-scoped, capped (oldest discarded, item deleted).
- Shop data caches for the account and the character.

Limited-stock shop state persists through `Ms2ex.Context.Shops`:
`character_shop_data` (owner id — account or character per the shop's
`account_wide` policy — plus shop id, restock deadline, restock count and
interval) and `character_shop_item_data` (owner + shop + entry id, purchased
counter, and the rolled item stored as a term so its stats survive until the
next restock). Default-interval shops (re-rolling every minute) are never
persisted. Purchases write their counter through immediately.

## Buy / sell

Buy: restricted-buy window checks (period, time-of-day ranges, day list) →
stock check (`sell_count - purchased`) → achievement requirement → inventory
space (free slot or stack space) → payment → stock counter update + `update`
packet → item created at the entry's rarity and added
(`add_item_or_mail`); the buy echo carries `sell_unit × quantity`.

Payment (`pay/3`): mesos and meret-family currencies debit the wallets;
item-priced entries consume the cost item across stacks; token currencies
(valor/treva/rue/havi fruit/meso token) debit their character or account
wallets.

Sell: the active shop must not be `is_only_sell`; the item's metadata must
allow vendor sale (`limit.shop_sell`). The vendor pays
`Formulas.Shop.sell_price/3` — the client's fixed prices for level 57+ gear,
otherwise the item's per-rarity (custom) sell price, with gear below
legendary selling at a third. The price is paid per sale (not per unit) and
the removed portion moves to the buy-back list at that price.

Restock: `instant_restock` pays the shop's price (with
`Formulas.Shop.excess_restock_cost/2` escalation when the multiplier is
enabled: flat meso fee for the first five restocks, then the excess currency
scaling 10→150), bumps `restock_count` and re-rolls the stock. `refresh`
re-rolls for free — the client sends it on scheduled restocks. Opening an
in-window shop overlays the persisted items/counters onto a fresh roll; an
expired window deletes the persisted data and rolls a new stock.

Resets: the midnight worker (`Context.DailyReset`) zeroes the restock
counters of day-interval shop data for online characters; on Thursdays the
same worker also clears week-interval data.

## Gaps

- Guild purchase requirements are unenforced: guild trophy totals,
  guild npc type/level, guild leader/fund checks and the 7-day membership
  gate need the guild achievement/trophy plumbing (there is a TODO at the
  check site).
- Championship rank/join-count and alliance (reputation) grade requirements
  are unenforced (no championship/alliance systems).
- Star point, mentor/mentee tokens, reverse coin and guild coin wallets do
  not exist; entries priced in those currencies are not purchasable.
- The `LoadNew` shop command (13) is unhandled.
- Beauty shops, the meret market and furnishing shops are separate systems
  (the beauty coupon and furnishing tables are already ingested).
- The client's display-only fields (`display_new`, sale amount) are always
  off/zero; `disable_display_order_sort` is passed through but sorting
  behavior is client-side.
