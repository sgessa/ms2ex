# Mob AI: aggro, chase & attack

Status: partial. Mobs acquire targets by proximity and on being hit, chase
the engaged player over the navmesh, stop inside attack range, and cast
their first skill entry against the target (with real damage). Not yet
implemented: multiple skill entries / rotation, attack-prism target
resolution, on-hit effects, and the client's AI scripts.

## How it works

### State

Each mob (`Types.FieldNpc`) carries `battle` — nil while idle, a map while
engaged: `target_id` (character id), `target_object_id` (player object id
for packets), `stop_range`, and the chase path state (`path`, `path_index`,
`goal`, `next_repath_at`, `last_move_at`). The next proximity-scan deadline
lives on the npc root (`next_target_scan_at`).

The battle update runs from the field tick (`Managers.Field.Npc.tick`, every
15ms): `Battle.tick/3` validates and drives engaged mobs, and scans for a
new target when idle. Friendly npcs (`type: :npc`) never engage.

### Target acquisition & retention

- scan cadence: every 500ms per idle mob
- candidates: every player on the field with a live synced position
  (`state.players` ∩ `state.player_positions`)
- acquisition band: metadata `distance.sight` radius (full 3D distance)
  with the `sight_height_up` / `sight_height_down` vertical band (the lower
  edge carries a +10 slack); closest candidate wins
- retention band: the wider `last_sight_radius` / `last_sight_height_up`
  / `last_sight_height_down`; the target is dropped the moment it leaves
  the field, escapes the band, or the mob itself is dragged more than
  `last_sight_radius` from its spawn point (the leash — no dedicated
  leash field exists in the data, so the give-up radius doubles as the
  leash; bosses with huge last-sight effectively never leash)
- hit-aggro: damaging a mob engages the attacker immediately
  (`Battle.aggro/3`, called from `Managers.Field.Npc.damage/4`) instead of
  waiting for the next scan. Because ranged pulls start outside the
  last-sight band, a hit-aggroed mob holds its attacker for at least 5
  seconds before the band drop applies
- sight radii are per-mob data and often small (many field mobs sit at
  400-900 units ≈ 4-9m); a mob engaged while already inside `stop_range`
  only turns to face the player, so without mob attacks an aggroed mob
  can be easy to miss until it closes distance

### Chase

While engaged and outside `stop_range`, the mob keeps a navmesh path to the
target's live position and walks it:

- paths come from `Navigation.find_path/3` (below); the mob runs at its
  metadata `action.run_speed` (units/second) with velocity broadcast through
  ControlNpc so the client interpolates
- re-path when the path is exhausted, the target drifted more than 150
  units from the pathed goal, or 500ms elapsed since the last path. An
  exhausted path is extended in the same tick so the run never stutters
  into a stand mid-chase (a stand tick restarts the client's walk
  animation and drops interpolation, which reads as flicker and
  micro-teleports); velocity carries across path corners for the same
  reason
- movement snaps onto the navmesh surface every step (`snap_to_floor`); a
  step with no walkable surface holds position — same rule as patrols
- inside `stop_range` the mob stands and faces its target
- no walkable route (target on another navmesh island, or the map has no
  mesh): the mob holds position and re-tries on the re-path cadence. A
  continuously unreachable target is dropped after ~4s of failed re-paths
  and the mob walks home — so perching on a ledge or island-hopping shakes
  aggro instead of freezing the mob in place. Range checks (sight,
  retention, stop range) are full 3D distances, so height counts: a mob
  directly below an unreachable ledge does not consider itself in range

`stop_range` is the mob's first skill entry's attack `range.distance`
(resolved through `Storage.Skills`), falling back to capsule radius + 80
(melee contact) for mobs without usable attack metadata.

### Cast cycle

A mob standing inside `stop_range` swings on cooldown: it pins itself in
place facing the target, plays the skill motion's sequence (state PcSkill,
16) through a 400ms windup, then the swing resolves at the hit moment —
damage only applies when the target is still within the attack range plus
60 slack, otherwise the swing whiffs (cooldown still runs). The cast
occupies the mob until the resolve; between swings it settles into
Attack_Idle_A (fallback Idle_A) while the cooldown runs.

- the active cast owns the mob's presentation: stand ticks during the
  windup never touch the animation, so the client plays the full swing
- every non-moving branch (stand, cast start, windup, resolve) touches
  the battle's `last_move_at`, so the first chase step after a cast
  integrates exactly the real elapsed time — without this, the step
  clamp turns the post-cast resume into a clamped 2-tick lurch (reads
  as the mob teleporting / moving very fast after every swing)
- animation changes during stands request a control send (swing →
  combat-idle), so the client sees the settle instead of looping the
  swing through the whole cooldown
- the hit flows to the field as an event; `Npc.tick` applies it through
  the character manager (`{:mob_hit, params}`), where the damage is
  computed against the character's own defenses (rate × mob physical
  attack × resistance factor ÷ defense × 4, mirroring the player→mob
  pipeline) — funneling death, regen deferral and the stat broadcast
  through the normal paths — and the field broadcasts the SkillDamage
  packet so every client sees the numbers
- cooldowns: `cooldown_time` from the skill level doc, floor of 750ms
  between swings

### Clock caveat

All mob deadlines (scan cadence, re-path windows, engagement holds) live
on `Ms2ex.sync_ticks/0` — monotonic ms since first call in this VM, always
starting at 0. The raw BEAM monotonic base itself can sit below zero, so
comparing a constant-0 (or otherwise absolute) deadline against raw
`System.monotonic_time` silently never fires; this is exactly what killed
sight aggro and aggro reset on first deployment. `Npc.tick`, the damage
path and every seed/comparison in `Field.Npc.Battle` and `FieldNpc` must
stay on the one base.

### Return home

When a mob loses its target while displaced from where it spawned (more
than 150 units away), it switches to a return walk: a navmesh path back to
its spawn point at run speed. It keeps scanning on the way and re-engages
a player who comes back into sight (or attacks it). Once within 60 units
of home it goes idle, heals to full, and clears its attacker tags so the
next fight tags its own attackers; the healed HP is announced with a stat
update. Mobs that lose aggro without having left their spawn area just go
idle. A mob killed on the way home keeps its damage records for drops and
experience.

### Control packets

- one control entry per packet for the periodic loop (single-npc controls,
  matching the wire behavior the client sees in normal play — multi-entry
  batches in the periodic loop froze mobs and lost HP-bar transitions on
  the client), plus state byte: Walk (2) while the mob is moving, PcSkill
  reaction (16) while engaged but standing — which is what arms the field
  HP bar — Idle (1) otherwise. Dead/corpse entries keep their dedicated
  single-entry forms
- boss target slot: while engaged, the aggro target's player object id
  (arms the boss HP bar); while idle, the field's default (nearest player),
  mirroring a freshly-aggroed boss
- animation: Run_A (or Walk_A) sequence id while chasing, Attack_Idle_A /
  Idle_A when standing in battle, Idle_A when disengaging

### Navmesh pathfinding (`Ms2ex.Navigation`)

The navmesh document per xblock stores tiles with vertices and polygon
vertex loops only — no polygon neighbor links — so the server builds its own
graph once per map (cached in `:persistent_term`): one node per convex
polygon, linked where polygons share an edge. Edges are welded by quantized
vertex position, which also connects polygons across tile borders (the
ingest bakes Detour tiles without neighbor data).

- nearest-polygon queries run over a uniform grid index (4m cells) with
  ring expansion, instead of scanning every polygon — this is what keeps
  per-step floor snapping cheap with many mobs
- `find_path/3`: closest walkable point for both endpoints, A* over polygon
  centers, then the funnel algorithm (string pulling) over the corridor's
  shared edges produces the final corner path
- no path (disconnected islands, off-mesh endpoint) → `:error`

Disconnected walkable islands are common in the generated meshes (small
props, ledges, phased quest rooms); paths within one island work, across
islands return :error.

## Metadata

The npc document carries an `ai_path` string (the client's AI script for
the npc) and a `distance` block (`sight`, `sight_height_up`,
`sight_height_down`, `last_sight_radius`, `last_sight_height_up`,
`last_sight_height_down`, `avoid`). Both are projected by the ingest;
`ai_path` is unused until the AI-tree runtime lands.

## Deliberate divergences

- hit-aggro: the reference acquires targets by proximity scan only — a
  player attacking from outside sight does not pull. Real aggro-on-hit is
  expected game behavior, so ms2ex engages the attacker directly.
- fixed battle routine: chase the target and stop inside attack range,
  instead of driving the mob from its AI XML battle tree. `stop_range`
  derives from the first skill's attack range rather than the tree's
  trace-node detect distance.
- engagement state byte: ms2ex holds PcSkill reaction (16) while engaged
  and standing (it arms the field HP bar); the reference reports Idle and
  sends PcSkill only during actual casts.
- idle boss target slot keeps the nearest-player fallback instead of zero.
- pathfinding is a self-contained A* + funnel over the shared navmesh
  documents instead of per-mob crowd agents; there is no crowd steering,
  no fly-advance, and no jump-link traversal.

## Still missing

- AI decision-tree runtime: the battle/battle-end XML trees (trace, skill,
  target-policy, conditions, weighted selects, per-node cool-times, ai
  presets, extra data) that drive per-mob combat behavior. `ai_path` is
  projected and ready to key them.
- mob skill casting beyond the first entry: skill rotation across entries,
  attack-prism target resolution (multi-target / splash), apply on-hit
  effects (dot, knockback, buffs). Single-entry cast + reverse damage
  pipeline + SkillDamage broadcast are done; player death flow exists.
- target policies beyond nearest: far / mid / random band / buff-marker
  / grabbed-user targets, aggro against other npcs (friendly == 1 mobs
  fight hostile mobs), pet taming behavior, summon/slave relationships.
- combat time tracking (battle-time conditions), jump/knockback handling,
  fly movement for airborne mobs.
