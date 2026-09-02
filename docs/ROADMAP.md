# MS2EX Roadmap

MS2EX is an open-source MapleStory 2 server emulator written in Elixir. This
document tracks the features the emulator is still missing or incomplete,
ordered by priority.

Status markers:

- **[Done]** — implemented and wired through metadata + server.
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

### 6. SkillDamage Tile damage mode — [Partial]

The DotDamage (0x3) record is implemented and driven by the buff tick loop.
The Tile (0x6) mode, tied to tile skills, is still unimplemented.

---

## P3 — Client parity & serialization

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
the first hit immediately.

### 11. RegionSkill rotation — [Done]

`RegionSkill` now zeros horizontal rotation for direction-less region skills while
keeping directional ones unchanged.

### 12. Party damage meter — [Open]

The client's party DPS meter never updates because the server never feeds it.
The client requests the meter via recv `0x57` (DpsMode) and expects periodic
send `0x88` (DpsStat) per-member damage totals; ms2ex drops `0x57` as an
unknown packet and never sends `0x88` (the reference declares both opcodes but
never implements them either). Field `SkillDamage` broadcasts already reach
party members byte-correctly, so this is purely the missing server-side
damage accumulation + `DpsStat` flow (see `docs/internal/party-dps-meter.md`).

---

## Recently completed

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
