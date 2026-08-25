# C# Reference Deltas

Tracker for differences between ms2ex and the C# reference implementation
(`../Maple2`). Each entry records the reference behavior, our current
behavior, and status. Update entries as investigations conclude.

## Object ID spaces

Reference:

- `FieldManager._globalIdCounter` (static, cross-field): starts at
  10,000,000 — players and mount action ids.
- `FieldManager.localIdCounter` (per field instance): starts at
  50,000,000 — NPCs, portals, spawn points, items.
- `Actor.localIdCounter` (per actor): starts at 1 — skill/effect entities.

ms2ex: players and mounts draw from the app-wide `Managers.GlobalCounter`
(10,000,000 base, first id 10,000,001); NPCs, portals, spawn points,
buffs and items share each field's `local_id_counter` (50,000,000 base)
via `Managers.Field.next_local_id/1`.

Status: **aligned**. Previously two independent counters both started at
10,000,000 (players per-field, mounts app-wide), so a mount could receive
the same object id as its rider; fixed by feeding both from the single
app-wide counter.

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

## FieldPickupItem (0x002D)

Reference (`ItemPickupPacket`): mesos carry a long amount, stamina an
int amount, every other item no amount at all.

Status: **fixed** — ms2ex previously always wrote a long amount.

## ControlNpc dead entries (0x002C?)

Reference (`NpcControlPacket.Dead` / `WriteNpcEntry`):

- Bosses write the target-id slot as `0`.
- Sequence counter is the NPC's real (incremented) value.
- While a corpse-hittable NPC awaits removal, its Dead entry is
  re-broadcast roughly once per second (`SequenceCounter++` each time).

ms2ex history: bosses sent their attacker's object id, the sequence
counter was hardcoded to 1, and death was announced exactly once.

Status: **fixed**; corpse re-announcements run in the field tick loop
(1s interval) gated on `npc.metadata.corpse.hit_able`.

## Stats — mob updates (0x0038?)

Reference (`StatsPacket.Update`): command byte `0`, attribute count,
attribute enum byte, then per-index values (Health as longs).

ms2ex: uses mode byte `0x1` with `[total, base, current]` longs. Mode
`0x0` makes this client expect a full 35-stat dump and drop the packet.

Status: **deliberate deviation** — empirically required by this client;
see the comment in `Packets.Stats.update_mob_stat/2`.

## Merets update (Meret opcode)

Reference (`CurrencyPacket.UpdateMeret`):
`[merets][extra][game merets][extra game merets][delta]`.

ms2ex history: the amount landed in the game-meret slot, the meret
balance was written as zero, and the delta was always zero — so pickups
never showed the client-side gain toast.

Status: **fixed**; `Context.Wallets.update` passes the increment as the
delta so pickup toasts render.

## Mounts / GlobalCounter

Reference: mount object ids come from the field's local counter.

ms2ex: app-wide `Managers.GlobalCounter` starting at 500,000,000. Its
old base (10,000,000) collided with first-player object ids.

Status: **deviation kept** (isolated range, shared across fields).

## Open / unaudited

- `StateSyncPacket` exists in the reference; no ms2ex equivalent examined.
- Death ordering details: the reference spawns some loot per damage tick
  (`OnDamageReceived` → `DropHitLoot`) and attributes damage via
  `HandleDamageDealers`; ms2ex only rolls rewards at death.
- Join-flow packets (`FieldAddUser`, `AddPortal`, battle packets) have
  not been diffed against the reference yet.
- Field boss HP bar (`UUIUpperHpBar`) never appears for NPCs in this
  client; parked pending deeper UI investigation.
