# C# Reference Deltas

Tracker for differences between ms2ex and the C# reference implementation
(`../Maple2`). Fully aligned areas are listed briefly at the top; detailed
entries cover what still differs. Update as investigations conclude.

## Aligned

- Object ID spaces (app-wide counter for players and mounts; per-field
  counter for npcs, portals, spawn points, buffs, items)
- FieldPickupItem amounts (meso long, stamina int, other items none)
- ControlNpc dead entries (boss target id 0, real sequence counters,
  periodic corpse re-announcements)
- Merets update layout and gain delta
- State sync (UserSync relay, RideSync relay with ride-state relabeling,
  SyncNumber)
- Mob stat updates (targeted attribute update on the standard stat
  command; the earlier "client drops it" finding was an artifact of
  stream corruption, not packet layout)

## FieldAddItem (0x002B)

Reference (`FieldPacket.DropItem`):

- Header tail after rarity: `short`, `bool FixedPosition`, `bool`.
- Non-meso drops append `WriteClass<Item>` (full `Item.WriteTo`).
- Mesos (90000001..90000003) append nothing.

ms2ex history: the tail was a stray int (`21`), mob-drop currency items
carried a hand-written "special" blob, and player drops reused the
inventory packet layout — all of which over-consumed on the client and
corrupted nearby entity state (unhittable field bosses, minimap icons
stuck at drop locations, missing death animations).

Status: **headers fixed** on both clauses; player drops serialize a
faithful default-state port of `Item.WriteTo`. Two open deviations:

1. **Trailing zero padding** (~64 ints) is appended to both clauses. The
   reference sends none. It acts as an over-consumption buffer while the
   exact expected tail length for this client build remains unverified.
2. **Mob-drop currency blob** still uses the legacy `count=1` + entry
   payload. It renders and picks up correctly with the corrected header,
   but the entry fields' true semantics are unknown.

## Open / unaudited

- Death ordering details: the reference spawns some loot per damage tick
  (`OnDamageReceived` → `DropHitLoot`) and attributes damage via
  `HandleDamageDealers`; ms2ex only rolls rewards at death.
- Join-flow packets (`FieldAddUser`, `AddPortal`, battle packets) have
  not been diffed against the reference yet.
- TODO: implement `RecvOp 0x21 StateSkill` — currently mislabeled as
  `INVENTORY_ITEM` in the recv table and dropped. Reference validates
  the cast (item owned, metadata exists, cast requested), tracks it in
  active skills, and relays it to other clients.
- Field boss HP bar (`UUIUpperHpBar`) never appears for NPCs in this
  client; parked pending deeper UI investigation.
