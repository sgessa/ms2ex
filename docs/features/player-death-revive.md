# Player death / revive

Status: death state + animation, tombstone, safe/instant revive and respawn
are implemented. Open: party/class revive skills, revive-voucher consumption,
daily instant-revive cap, auto-revive maps. The "tombstone can be hit by
other players" flow is still broken client-side: the tombstone renders but has
no collision, so skills pass through it.

## Protocol

Recv:

- `0x1F` REVIVAL — byte command (`0` safe, `2` instant); instant reads a
  bool `use_voucher` after the command.
- `0x2A` TOMBSTONE — int `object_id` (dead player), int `hits`.

Send:

- `0x34` REVIVAL_CONFIRM — int `object_id`, int `end_tick`, int `count`
  (death penalty end tick + death count). Already existed, now re-sent on
  death.
- `0x35` REVIVAL — int `object_id`, byte 0 (revive broadcast).
- `0x36` REVIVAL_COUNT — int count (instant revives used).
- `0x5E` TOMBSTONE — int `object_id`, byte `hits_remaining`,
  byte `total_hit_count`, int 1, bool false.
- `0xA8` DEAD_USER — int `object_id`, bool `dark_tomb`.
- `ProxyGameObj` update_player with the `dead` flag (0x01) + bool dead is
  broadcast on die and revive.

## Death flow

All HP reductions funnel through `Managers.Character`'s stat casts; a
`maybe_die/1` check after each fires once when `health_cur <= 0` and the
character isn't already dead. `die/1`:

1. bumps `death_count`, sets `death_penalty_end_tick = now + penalty_tick`,
   sets `dead?`.
2. broadcasts `DeadUser` (dark tomb on `only_dark_tomb` maps or repeat
   deaths), `ProxyGameObj.update_dead`, and raises the `Tombstone` entity in
   the field.
3. pushes `RevivalCount` + `RevivalConfirm` to the dead player so the
   post-death HUD arms.

## Revive flow

Safe revive (`0`): refuses on `no_revival_here` maps; restores full HP,
clears `dead?`, broadcasts `Revival` + dead-flag clear, removes the
tombstone, then respawns at the map spawn — or `change_field`s to the map's
`revival_return_id` when set and different.

Instant revive (`2`): costs mesos (`level * 10`, free ≤ level 8) or a
free-revive coupon; revives in place without moving.

Tombstone hits (`0x2A`) reduce `hits_remaining`; at 0 the field casts a safe
revive to the owner.

## Tombstone visibility on field entry

No dedicated `Tombstone` (0x5E) packet is sent on field entry
(that frame is broadcast only when `HitsRemaining` changes, i.e. on hit). A joining
player learns an existing tombstone from two fields the server already sends:

- `FieldAddUser` (0x17) character block: `WriteShort(character.DeathCount)`
  right after the current/max health ints.
- `ProxyGameObj` AddPlayer (mode 0x3): `WriteBool(IsDead)`.

The client uses the death count to build the targetable/collidable tombstone
entity (hit count = `death_count * hitPerDeadCount` capped). ms2ex previously
wrote `0` for the death count in `FieldAddUser`, so the tombstone rendered
(from the dead flag / death animation) but had no hit box — skills passed
through it. `FieldAddUser` now forwards the peer's `death_count` into
`CharacterList.put_character/3` (the shared helper defaults to 0 for the login
list and party).

**Still open:** even with the death count in `FieldAddUser`, other players
cannot hit the tombstone in-field. The client renders the tombstone model but
does not register a collidable target object, so skills pass through. The
expected payload builds it from the dead flag + death count on field entry (and
re-broadcasts the dead flag via `ProxyGameObj` update on in-field death, which
ms2ex also sends on `die`/`revive`), so the remaining divergence is likely
elsewhere in how the proxy object / dead state reaches already-connected
clients. Compare against a live capture of a working server's death +
tombstone-hit sequence before closing this item.

## Metadata

The ingest projects the revival map-property fields
(`revival_return_id`, `no_revival_here`, `only_dark_tomb`, `death_penalty`,
`auto_revival_*`, ...) into the `map:<id>` document. ms2ex reads them via
`Storage.Maps.get_property/1`.

Server-table constants (`hitPerDeadCount`, `maxDeadCount`,
`UserRevivalPaneltyTick`) are app-config defaults until the constants table
is projected.

## Persistence

The death penalty (`death_count`, `death_tick`) and the daily instant-revive
counter (`instant_revive_count`) are persisted on the `characters` row
(columns added by migration 85). They survive server restarts. The daily
counter is cleared by `Ms2ex.Workers.DailyReset`, an Oban job fired by a
crontab entry (`Oban.Plugins.Cron`, `0 0 * * *` UTC). The worker zeroes the
DB column for every character and casts `:reset_daily_revives` to each
connected character manager so in-memory state and the client "uses left"
gauge reset too. The reset matches the client's per-day
`InstantRevivalCount` display via a midnight server tick.

`dead?` stays a virtual (session-only) field: logging in always revives the
character.

## Dependencies

Oban (job queue + crontab) was added for the daily reset. Migrations 85
(revival state columns) and 90 (Oban tables) must be applied.

## Still open

- party / class revive skills (reviving a fallen teammate with a skill)
- free-revive coupon consumption (`use_voucher` on the instant revive)
- daily instant-revive cap enforcement
- auto-revive maps (`auto_revival_type` / `auto_revival_time`)
- FieldAddUser for peers writes zero health total/current instead of the
  real values (join-flow audit item)
- tombstones have no collision: basic attacks pass through them, only skills
  can hit the revive target
