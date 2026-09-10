# Guild system

Status: core membership flows work — create/disband, invites, search,
applications, expel, leave, leadership transfer, rank editing,
notice/emblem/focus updates, member mottos, check-in and donation, guild
mail, guild chat (+ alert variant gated on the rank permission), UGC emblems
and posters, and presence/PubSub wiring across every join/leave path.

## Still missing or stubbed

- guild buffs, personal buffs, buff upgrades (`UseBuff` 0x58,
  `UsePersonalBuff` 0x59, `UpgradeBuff` 0x5A), npc upgrades (`UpgradeNpc`
  0x6F), gifting (`SendGift` 0x6A, `UpdateGiftLog` 0x6D), capacity increase
  (`IncreaseCapacity` 0x40): opcodes are wired and accepted but parse-only —
  no funds/cost deduction, no buff/npc level change, no gift log. Only the
  metadata (`guild.xml` cost/level/duration tables) and default buff seeding
  at creation exist; real behavior needs to be designed
- guild arcade/raids (`StartArcade` 0x60, `EnterArcade` 0x61) and guild
  events (0x70/0x71/0x75): no packet handling, no room/instance model
- guild house: enter/upgrade persist, but the house map has no content
  (depends on the housing cube system)
- `ListApplications`/`ListAppliedGuilds` wire format is the least-trusted
  packet in the system (derived from client crash analysis; no known-good
  layout to compare against)
- guild leveling not verified end-to-end against rank-up thresholds
- search results do not reflect "already applied" state client-side
