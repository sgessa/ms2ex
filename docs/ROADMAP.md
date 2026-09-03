# MS2EX Roadmap

MS2EX is an open-source MapleStory 2 server emulator written in Elixir. This
document tracks the features the emulator is still missing or incomplete,
ordered by priority.

Status markers:

- **[Partial]** — some pieces are in place; the rest is tracked under the item.
- **[Open]** — not started.

Priorities:

- **P1 — Core combat loop** — without these, combat cannot be meaningfully
  fought or lost.
- **P2 — Combat systems depth** — systems that make builds, classes and
  encounters interesting.
- **P3 — Client parity & serialization** — byte-level compatibility with the
  game client.

---

## P1 — Core combat loop

### 1. Player death & revive — [Partial]

What is still missing:

- party / class revive skills (reviving a fallen teammate with a skill)
- free-revive coupon consumption
- auto-revive maps (`auto_revival_type` / `auto_revival_time`)

### 2. Mob AI: aggro & damage — [Open]

Mobs never target players. They do not aggro, chase, or attack, so mob→player
damage stat broadcasts do not exist yet. Today the client can only fight
back — mobs cannot fight at all.

### 3. Damage pipeline completeness — [Partial]

The damage formula is in place and rate-based DoT ticks reuse it. What is
still skipped:

- miss / block / evade rolls
- element, range and NPC-damage bonuses
- pierce resolved with the exact client formula (still a capped share)

Flat skill damage (`damage.value`) is applied from metadata, and DoT damage
scales with the caster's attack via the shared formula.

### 13. Mob spawn cycles — [Partial]

Mob spawn points now run spawn cycles from the field tick loop: the initial
population spawns on the first due cycle, mob deaths schedule the next cycle
(full wipe → `regen_check_time` cooldown, partial kill → 2× cooldown while no
cycle is pending), and every due cycle refills the population to full.
Zero-cooldown spawns never refill. What is still missing:

- pet spawn rolls for mob spawns (`pet_population` / `pet_spawn_rate`) — the
  metadata is not projected by the ingest yet
- navmesh-valid spawn position picking — mobs currently randomize ±250 around
  the spawn point instead of snapping to map spawn volumes
- friendly NPC spawn points are still spawned eagerly at field load; their
  trigger-driven creation and `regen_check_time` top-up checks are not
  implemented

---

## P2 — Combat systems depth

### 4. Buff & effect system gaps — [Partial]

Applied today: `status.values` / `status.rates` stat modifiers, the
`update.cancel` removal list, stacking via `overlap_count` /
`modify_overlap`, tick skills, and recovery. What is still missing:

- `status.special_values` / `status.special_rates` (special attributes granted
  by buffs, such as damage-type multipliers) — metadata is projected and
  item-granted special stats are applied, but buff-granted ones are not
- `ApplyCancel` buff removal
- non-tick effect skills only fire at max stacks; combat-event triggers
  (on-hit / on-attacked / on-death) are not evaluated
- condition and immune-category checks are not evaluated
- recovery is skipped on mob-owned buffs; empty effects are applied as no-op
  buffs
- item-granted buffs (equip effects with buff payloads) are not applied or
  removed on unequip

### 6. SkillDamage Tile damage mode — [Partial]

The DotDamage (0x3) record is implemented and driven by the buff tick loop.
The Tile (0x6) mode, tied to tile skills, is still unimplemented.

---

## P3 — Client parity & serialization

### 17. Item systems: gem sockets, pet items, gacha — [Open]

The item packet writes the reference defaults for three systems ms2ex does
not implement, so every item currently serializes identically to an item
without those features: the gacha dismantle id (always 0), the pet info
block (never written), and gemstone sockets (empty socket block only;
socket unlocking and gemstones are unimplemented). Implementing any of
these needs the feature system plus, for pets, ingest projection of pet
metadata.

### 7. Join-flow packet audit — [Open]

`FieldAddUser`, `AddPortal` and the battle-join packet set have not been
audited for byte-level client parity yet.

### 8. Drop & field-item serialization — [Open]

The drop packet still has three deviations:

- ~64 ints of trailing zero padding on both clauses (the client expects none)
- mob-drop currency items still use a legacy `count=1` + entry payload
- SP/stamina/merets use the legacy currency blob instead of the full item
  class

### 9. Region & splash attacks — [Partial]

`ImmediateActive` / `Delay` are now projected by the ingest, but the server
still uses a fixed radius instead of the exact skill geometry and always lands
the first hit immediately. Cube-magic-path placement also still has parity
work left: rotated `fire_offset` is applied, but source-height alignment and
`ignore_adjust` snapping are not matched yet.

### 12. Party damage meter — [Open]

The client's party DPS meter never updates because the server never feeds it.
The client requests the meter via recv `0x57` (DpsMode) and expects periodic
send `0x88` (DpsStat) per-member damage totals; ms2ex drops `0x57` as an
unknown packet and never sends `0x88` (the reference declares both opcodes but
never implements them either). Field `SkillDamage` broadcasts already reach
party members byte-correctly, so this is purely the missing server-side
damage accumulation + `DpsStat` flow (see `docs/internal/party-dps-meter.md`).

### 14. Quest flow — [Partial]

A first quest baseline is wired: quest recv/send opcodes are registered,
quest-state packets can serialize, character/account quest rows can persist
(including live condition-counter updates), quest metadata is projected into
Redis with a quest index, field-enter
restores quest state plus the basic `map` condition update, NPC interact can
surface the available-quest list, quest talk scripts drive the dialogue state
selection (accept/progress/complete), basic auto-start quests are seeded, and
common reward delivery now covers exp, mesos, treva, rue, and essential item
grants.

Condition hooks now fire from gameplay: mob kills (`npc`), skill casts
(`skill`), level ups (`level` / `level_up`), field pickups (`item_pickup`),
inventory acquisition (`item_add` / `item_exist`), emote use (`emotion`,
matched on the client-sent animation key), taxi rides, meso pickups, chat,
tombstone hits, buddy requests and exp gain. Progress matching follows the
metadata layout: code-parameter id/string containment plus target
minimum-value / allowed-value gates.

Completion and acceptance commit the quest row, turn-in item consumption
(`item_exist` conditions) and item rewards atomically in one transaction;
exp and currencies are granted post-commit. Non-
forfeitable quests refuse abandon, the expiration sweep drops rows and
notifies the client, and go-to-npc travel moves the character to the quest's
destination map.
What is still missing:

- multi-page npc dialogue walking (Continue tracking) and script functions
  (rewards/portal/cutscene side effects inside dialogues)
- interact object lifecycle beyond the state machine: gathering/mastery
  yields, telescope unlock exp, drop tables and additional effects on
  interact
- condition sources for breakables (`breakable_object`), triggers, fishing,
  and the long-tail condition types
- selective rewards, mail fallback for full inventories, and the remaining
  reward-side edge cases
- field-mission exploration progress, chapter rewards, job-advance hooks, and
  the remaining quest subcommands

---

## P4 — Architecture

### 15. Character-owned inventory — [Open]

Inventory lives in Postgres behind stateless `Context.Inventory` calls today;
every item interaction pays a query round-trip and read paths (e.g.
`item_exist` conditions) re-query rather than trust a cached copy. The
long-term model is full ownership in memory, genre-standard for MMO servers:

- an `inventory_manager:<char_id>` GenServer (like the quest manager) owning
  all item reads/writes, loaded on login, write-through on mutation, flushed
  on logout
- every call site routed through it: pickup/drop, consume, move/split/merge,
  equip changes, rewards, and shops/trades/storage/mail as those features
  arrive; slot allocation (`find_first_available_slot`) becomes a scan over
  the owned item list bounded by the tab's persisted slot count instead of a
  per-write query against hardcoded slot ranges
- the completion-time `Repo.transaction` atomicity (quest row + turn-in
  consumption + rewards) becomes in-process ordering inside the manager, since
  a DB transaction cannot span its memory
- trigger points for doing this: item-flow features landing (shops, trades,
  storage, mail), `item_exist` checks feeling heavy, or growth beyond a
  single node
- explicitly rejected: read-caches layered over the DB — two sources of truth
  with the classic invalidation bugs, and none of the ownership benefits
- when this lands, equips fold into it (they are items with
  `location: :equipment`) rather than keeping a separate equip owner

### 18. Metadata-free manager state — [Open]

Metadata documents are virtual fields on items and get embedded wherever
structs are cached in GenServer state, so manager memory grows with document
sizes instead of entity counts. The item side is lean now: the character
manager's cached equip list and the field manager's dropped items hold rows
without metadata and re-read the storage cache at point of use (stat
rebuilds, pickup). Still holding documents in state:

- `Types.Npc` keeps npc metadata per field NPC (mob AI, spawns, drop rolls
  and corpses read it)
- the quest manager caches the quest metadata document on every active quest
- `Types.Buff` keeps the full effect document on every active buff

Replacing those with fetch-from-cache-at-use keeps long-lived fields and
combat-heavy characters from accumulating document copies.

---

## Recently completed

- Equipment state extraction: equip transitions moved into the character
  process (`Managers.Character.Equips`, like `.Experience` / `.Stats`) — one
  manager call runs the whole equip/unequip and returns fresh state, and
  character info reads the manager's equip list instead of re-querying.
  Deliberately a module split, **not** a separate GenServer: equips are read
  constantly by field serialization of other players and are items (see
  item 15), so a standalone equip process would fragment item state across
  two owners
- Equip parity & slot allocation: slot scans are bounded by the tab's
  persisted slot count (base + expansions) instead of a hardcoded range, and
  free-slot counting feeds the multi-slot equip pre-check; the equip
  transition now validates the request (target slot must be the item's
  primary slot, level/expiry/job limits, localized error boxes), resolves
  conflicts and unequips in the reference order (vacated slot preferred,
  full-inventory refusal), and discards cosmetic looks (hair/ears/face/face
  decal) on unequip. Pickups no longer lose the drop when the inventory is
  full — the field item stays
- Manager state carries no item metadata: the cached equip list and field
  drops hold plain item rows, and stat rebuilds, gear score, and pickup
  re-read the storage cache (ETS) at point of use

- Quest command surface: forfeit enforcement (non-forfeitable quests refuse
  abandon), the client expiration sweep (drops persisted rows and acknowledges
  with the expired-quest packet), and go-to-npc travel to a started quest's
  destination map

- Mob respawns: mob spawn points refill their population through tick-driven
  spawn cycles, scheduled by mob deaths (wipe → cooldown, partial kill → 2×
  cooldown, zero cooldown → never)
- RegionSkill rotation: direction-less region skills now zero horizontal
  rotation while directional ones keep it; region-splash damage no longer
  crashes on hit, and regular-skill spirit drains now persist so Wizard SP
  regen matches observed timing (immediate start, minimum 100ms tick floor)
- Passive HP/SP/stamina regen fix: inverted dead-actor guard on
  `Character.Stats.regen/2` (from #88) meant living characters never
  regenerated; exposed by the Swift Swim stamina drain. Consumption now
  also suspends HP/stamina regen for the projected Recovery*WaitTick
  (new server.constants.xml ingest doc), so drains deplete instead of
  racing regen. Regular active-skill SP drains now persist in the
  character manager too, so spirit regen resumes after normal casts as
  well as state skills; passive regen ticks now also clamp to a minimum
  interval so negative rate bonuses cannot collapse them to zero delay
  ([#98](https://github.com/sgessa/ms2ex/pull/98))
- State-skill resource costs: cast validation + consumption, per-tick drain
  loop at the projected motion `sequence_speed`, cancellation on state
  mismatch / death / resource exhaustion
  ([#98](https://github.com/sgessa/ms2ex/pull/98))
- Tombstone hit/revive flow: peer HP in `FieldAddUser`, plus death-flow
  parity (gauge packet, revive order, penalty-window death count)
  ([#97](https://github.com/sgessa/ms2ex/pull/97))
- Player death & revive: death state + animation, tombstone entity, post-death
  HUD, safe/instant revive
  ([#80](https://github.com/sgessa/ms2ex/pull/80))
- Field monster HP bar: player id in `ServerEnter` + validated field key in
  `RequestFieldEnter` ([#84](https://github.com/sgessa/ms2ex/pull/84))
- Equip stat bonuses: random options, enchant / limit-break enchants,
  special-value / special-rate stats, rate-type stats
  ([#74](https://github.com/sgessa/ms2ex/pull/74))
- Flat skill damage (`damage.value`) applied from metadata
  ([#71](https://github.com/sgessa/ms2ex/pull/71),
  [ingest@218025f](https://github.com/sgessa/ms2ex-file-ingest/commit/218025f))
- On-hit skill effects: `skills_on_damage` applied alongside attack condition
  skills ([#71](https://github.com/sgessa/ms2ex/pull/71),
  [ingest@218025f](https://github.com/sgessa/ms2ex-file-ingest/commit/218025f))
- SkillDamage DotDamage (0x3) record
  ([#71](https://github.com/sgessa/ms2ex/pull/71))
- Buff `status.special_values` / `special_rates` metadata projection
  ([ingest@50681d4](https://github.com/sgessa/ms2ex-file-ingest/commit/50681d4))
- Region splash `ImmediateActive` / `Delay` metadata projection
  ([ingest@50681d4](https://github.com/sgessa/ms2ex-file-ingest/commit/50681d4))
- Skill cooldowns (`0x43`), incl. restore on field change and buff resets
  ([#68](https://github.com/sgessa/ms2ex/pull/68))
- Buff tick loop: DoT, recovery, tick skills, stacking, cancel-on-apply
  ([#73](https://github.com/sgessa/ms2ex/pull/73))
- Monster drops: death / hit / corpse, smart-drop weighting, character
  binding, map gating, tradeability ([#64](https://github.com/sgessa/ms2ex/pull/64))
- Item-skill & recovery consumables; buff expiry
  ([#69](https://github.com/sgessa/ms2ex/pull/69))
- State skills (recv `0x21`) ([#66](https://github.com/sgessa/ms2ex/pull/66))
- Field-load packets & skill target/damage relay
  ([#63](https://github.com/sgessa/ms2ex/pull/63))
- Fall damage & out-of-bounds teleport
  ([#67](https://github.com/sgessa/ms2ex/pull/67))
- Boss HP bar packet set, mob stat updates, player entity sync
  ([#59](https://github.com/sgessa/ms2ex/pull/59))
