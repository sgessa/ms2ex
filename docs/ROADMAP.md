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

### 1. Player death & revive — [Open]

Players cannot die yet. HP dropping to 0 has no effect, and fall damage is
capped at 25% of current HP, so it can never kill. Missing: the death state and
animation, a revive/respawn flow (respawn point, party/class revives), and the
client's post-death HUD state (`RevivalCount`/`RevivalConfirm` are only sent on
field entry today).

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

### 5. Skill resource costs — [Open]

Skills track cooldowns, but SP/stamina costs are never consumed: regular casts
skip them entirely, and state skills (recv `0x21`) have no per-tick
re-validation/consumption loop and are never cancelled when the actor state
changes.

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

### 10. Field boss HP bar — [Open]

The top-center boss HP bar never renders for NPC bosses in this client build.
The server-side packet set is aligned; the arming trigger is believed to be
client-side and needs a live sniff diff during a boss fight (investigation
notes are kept local).

### 11. RegionSkill rotation — [Open]

`RegionSkill` always sends rotation where direction-less skills should zero it.

---

## Recently completed

- Equip stat bonuses: random options, enchant / limit-break enchants,
  special-value / special-rate stats, and rate-type stats (e.g. perfect guard)
  now aggregate over equipped gear and apply to the character
- Flat skill damage (`damage.value`) applied from metadata
- On-hit skill effects: `skills_on_damage` projected and applied alongside
  attack condition skills
- SkillDamage DotDamage (0x3) record
- Buff `status.special_values` / `special_rates` metadata projection
- Region splash `ImmediateActive` / `Delay` metadata projection
- Skill cooldowns (`0x43`), including restore on field change and
  buff-triggered resets
- Buff tick loop: DoT, recovery, tick skills, stacking (`overlap_count` /
  `modify_overlap`), cancel-on-apply
- Monster drops: death / hit / corpse, smart-drop weighting, character
  binding, map gating, tradeability
- Item-skill & recovery consumables; buff expiry
- State skills (recv `0x21`)
- Field-load packets & skill target/damage relay
- Complete item drops
- Fall damage & out-of-bounds teleport
- Boss HP bar packet set, mob stat updates, player entity sync