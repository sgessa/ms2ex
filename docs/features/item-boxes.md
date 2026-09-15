# Item boxes & use-item functions

Status: boxes open through the dedicated `RequestItemBox` handler with the
`ItemBox.Open` response packet: contents resolve from the box's function
parameters against the individual/global drop tables at open time and roll
through the shared drop logic (level gates, gender filters, job weighting,
smart drop). OpenItemBox, SelectItemBox and OpenItemBoxWithKey are
implemented with multi-open counts, error codes, and correct currency drops
(meso/meret/valor/rue/havi/treva wallets, experience orbs); a failed grant
stops the open instead of losing the box. Boxes without drop-table content
in this client's data refuse to open.

Usable-item functions implemented in `USE_ITEM` include title scrolls,
story books, quest scrolls, inventory expansion items, premium coupons,
chat-sticker unlocks, party recall, additional effects, fishing bait, and
the three standard item-box functions.

## Still missing or blocked

- gacha and Lullu box variants (need the gacha tables and `ItemScript.Gacha`)
- spirit/stamina orbs (need the orb wallet/stat behavior)
- the transcendence crystal special case (needs its item-type metadata and
	reward semantics)
- beauty/remake/socket/repacking scroll workflows (need their UI request and
	result protocols)
- buddy badge boxes (need cross-character mail/item-couple persistence)
- massive portals, defense guards, HongBao, and air-taxi items (need the
	corresponding field objects, NPC lifecycle, event, and taxi systems)
- character-slot vouchers (need account character-cap persistence)
