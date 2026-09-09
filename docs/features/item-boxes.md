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

## Still missing

- gacha and Lullu box variants (need the gacha tables and `ItemScript.Gacha`)
- spirit/stamina orbs
- the transcendence crystal special case
