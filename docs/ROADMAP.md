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
Zero-cooldown spawns never refill. Mob bodies now stay for their `dead.time`
window before removal. Event spawn points (script-summoned mobs, the
reference's `EventSpawnPointNPC`, ingested with `is_event: true`) are
one-shot: they only appear through a `spawn_monster` trigger action and
never join the regen machinery — quest fights like the soulbinder
arena no longer resurrect their mobs every 10 s. Spawn-point npcs carry
an explicit `spawn_radius` from the map data now: zero (the flat-buffer
default) spawns the npc exactly at its configured position, and a
positive radius scatters it within a circle of that size — a blanket
±250 box jitter applied to every mob regardless of its actual radius
used to displace scripted gate guards (e.g. the classic tutorial's exit
barrier) far enough that skill hit-detection missed them outright. Open-world
population spawns still carry no radius metadata and keep the coarse
spread (see below). Monster gates are data-driven from the map's trigger
script (ingested as `mob_gates`): when the last mob of a gated spawn point
dies, the blocking trigger meshes drop (update packets broadcast, the gate
stays latched open across respawns, late joiners load the meshes hidden) and
the gate's guide event fires. What is still missing:

- pet spawn rolls for mob spawns (`pet_population` / `pet_spawn_rate`) — the
  metadata is not projected by the ingest yet
- navmesh-valid spawn position picking for open-world population spawns —
  they have no per-spawn radius metadata yet and still randomize ±250
  around the spawn point instead of snapping to map spawn volumes
- a general trigger-script runtime (states, conditions, cinematic/movie
  actions, per-job portal enables) — done; the machine core now runs on
  every map that ships trigger scripts, with
  wait-tick / user-detect / monster-dead / widget / quest-user-detect
  conditions and mesh, portal, monster, guide-event, movie, cinematic-ui,
  camera-path, effect, cinematic-talk and user-teleport actions; still
  missing: npc patrol movement, sound setup, cinematic transitions
  (types 3-6), movie skip via set_skip-armed scripts is in, patrol-driven
  user path movement is not

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
- buffs are restored per character, but not per **account** — buffs are not
  carried between characters on the same account, and a buff whose caster was
  another player is restored as if the owner had cast it

### 6. SkillDamage Tile damage mode — [Partial]

The DotDamage (0x3) record is implemented and driven by the buff tick loop.
The Tile (0x6) mode, tied to tile skills, is still unimplemented.

---

## P3 — Client parity & serialization

### 23. Fishing bait-slot UI sync — [Partial]

Fishing bait mechanics are partially implemented: bait/lure items ingest with
`property.tag = :fishing_lure`, fish metadata includes lure rows and
`bait_effect_ids`, using a bait item skill applies the timed lure buff,
consumes the inventory stack, pushes the shared bait cooldown, and fishing rolls
can use the active lure buff.

What is still missing:

- the client bait-slot amount does not refresh when the inventory stack is
  consumed; the normal `INVENTORY_ITEM` update refreshes the inventory tab, but
  the fishing bait slot keeps its old cached count until the player removes and
  re-adds the bait
- the "Use autobait" toggle has no server-side model yet; it likely needs state
  for auto-reapplying a lure when the active timed bait buff expires
- the dedicated bait-slot packet or fishing subcommand is unknown. The C#
  reference has no implementation for this either, so we need to reverse the
  client around bait slot add/remove, bait use, and autobait toggle packets

### 22. Insignia condition types — [Partial]

The name tag symbol is complete against the reference: the id is validated
against `nametagsymbol.xml`, persisted, its buff swapped on change, and the
display flag broadcast and written into the field-add-user payload. Six of
the twelve condition types are evaluated (`title`, `level`, `enchant`,
`trophy_point`, `adventure_level`, `vip`).

What is still missing:

- **`burning` and `survival_level`** never display (one insignia each in
  `nametagsymbol.xml`). The reference does not implement them either — it
  logs "Unhandled insignia condition type" — and each needs a system ms2ex
  has no model for: burning-event characters and Maple Survival levels.
  `tencentvip`, `gm` and `tgp` exist in the enum but no insignia uses them
- **conditions are only evaluated when the insignia is equipped**, so a
  symbol keeps showing after its condition lapses (premium expiring, the
  enchanted gear coming off, a level reset). The reference has the same
  behaviour; a re-check on the events that can invalidate a condition would
  need a hook per condition type
- **the thresholds are hardcoded** (level 50, 1000 trophy points, prestige
  100, 12 enchants / rarity > 3), matching the reference. Only `title` reads
  the table's `code` column, so the rest cannot be retuned from metadata

### 19. Housing & UGC cube system — [Open]

The cube packet surface is almost entirely unimplemented: `RequestCube`
handles only `remove_cube` (0x0C); every other mode falls into the
unhandled-mode warning — hold cube, buy/forfeit/extend plot, place/rotate/
replace cube, liftup object / liftup drop (0x11 is what the client sends
when a player grabs a placed furnishing), home name / passcode / vote /
message, clear cubes, plot area and height changes, design rank rewards,
permissions, save/load home, blueprints, kick out, and background /
lighting / camera. Plots, furnishings and home ownership have no server
model yet; the field-load cube packets send empty data.

### 17. Item systems: gem sockets, pet items, gacha — [Open]

The item packet writes the reference defaults for three systems ms2ex does
not implement, so every item currently serializes identically to an item
without those features: the gacha dismantle id (always 0), the pet info
block (never written), and gemstone sockets (empty socket block only;
socket unlocking and gemstones are unimplemented). Implementing any of
these needs the feature system plus, for pets, ingest projection of pet
metadata.

### 21. Item boxes & use-item functions — [Partial]

Boxes open through the dedicated `RequestItemBox` handler with the
`ItemBox.Open` response packet: contents are resolved from the box's
function parameters against the individual/global drop tables at open
time and rolled through the shared drop logic (`Context.Drops`, also
used by mob loot — level gates, gender filters, job weighting, smart
drop). OpenItemBox, SelectItemBox and OpenItemBoxWithKey are
implemented with multi-open counts, reference error codes, and correct
currency drops (meso/meret/valor/rue/havi/treva wallets, experience
orbs); a failed grant stops the open instead of losing the box.

Remaining: gacha and Lullu box variants (need the gacha tables and
`ItemScript.Gacha`), spirit/stamina orbs, and the transcendence
crystal special case. Some boxes have no drop-table content in this
client's data (e.g. the welcome pack 20300002) — those refuse to open,
matching the reference.

### 22. Character tutorial — [Partial]

New characters spawn on their job's tutorial start field (from the job
table projection instead of a hardcoded map), the client's
`REQUEST_TUTORIAL_ITEM` request grants the job's starter items
idempotently (level-1 characters on the start field only, topping up
what they do not already hold), walking out of the start field at
level 1 grants the tutorial reward items and unlocks the tutorial's maps
and taxis (persisted, with taxi-discover packets), and the tutorial skip
item teleports to the skip destination when used on the start field. Guide
pop-up progress (`GuideRecord`) is persisted per character and replayed to
the client on field enter.

The classic tutorial chain (start field → knight training yard) runs on
the trigger-script runtime (see the trigger runtime item): the barrier
monster gate, the squire-carry quest (liftable pickup/install firing the
item_move condition), job-portal selection, and the map-exit teleport all
play through the xblock scripts.

The newer-class tutorials (runeblade 63000006-chain, striker
63000015-chain, soulbinder 63000035-chain) are scripted quest campaigns
(walk-and-talk states, movies, npc choreography, quest-state gates —
e.g. striker's `63000015_cs/intro01.xml` has 37 states around quest
90000430). The runtime now runs on every scripted map and warns on
unimplemented actions, so each chain's remaining coverage surfaces
during a test run; until verified, those characters skip via the job's
skip item (`!item 15500095` for a striker, then use it on the start
field).

### 23. Trigger-script runtime — [Partial]

The xblock trigger scripts run on every map that has them (per-script
state machines tick at 100ms with the semantics described above:
on-enter actions, first-true-condition transitions, WaitTick against
state entry, entrance transition skipping one cycle). Unimplemented
actions warn in the server log so coverage gaps surface per map.
Conditions: user_detected
(job-gated, padded boxes), monster_dead, quest_user_detected (the
reference's wanted states: 1 started-not-completable, 2 completable,
3 completed), npc_detected (a story npc's spawn point standing inside a
box — drives scripted arrivals, e.g. an npc that walked off through
move_npc reaching its destination), widget_condition (Guide/SceneMovie),
negate. Int-list
arguments accept single ids, comma lists and inclusive ranges
(`5001-5025` → every id — this drives the tutorial's arrow trails).
Actions: set_mesh/set_effect, set_portal, spawn/destroy_monster (mob and
friendly spawns), guide_event, create/widget_action, play_scene_movie,
set_cinematic_ui, set_onetime_effect, select_camera_path/reset_camera,
add_cinematic_talk, set_dialogue (player/npc speech balloons and
cinematic talks), set_npc_emotion_loop + set_npc_emotion_sequence
(emote sequences resolved through the model's animation table),
move_npc (story npc walks a named patrol, staying at the last
waypoint), set_pc_emotion_loop (the client loops the player's emote
for the duration), set_pc_emotion_sequence (the player plays a
comma list of emote sequences back to back),
show/hide_guide_summary (held while a
cinematic or scripted path move has the player and flushed when control
returns), set_skip + set_scene_skip + skip-cutscene handling,
show_caption (the screen-space named-title card ending a scripted
beat), set_achievement (a trigger condition event for players in a
box, feeding the quest and achievement pipelines — this is what lets
trigger-gated main quests such as the knight's complete),
add/remove_buff (script buffs), move_user (same-map teleport refused for
non-walkable portals via the navmesh, cross-map field change),
move_user_path (invisible follow-dummy walks the patrol in 3D with
velocity while the client walks the player behind it), create_item (a
map's item spawn point drops a fixed-position, unowned field item —
used directly when the action names an item id, or rolled from the
spawn point's own individual/global drop box), set_time_scale (a new
`TimeScale` opcode ramps the field's tick rate between two scales over
a duration — cinematic bullet-time/slow-mo beats).

Still missing:

- camera cutscene fidelity: scripted camera paths play, but the revert
  behavior diverges (camera keeps drifting after the spline, player
  movement is not locked during scripted cameras); needs a packet-level
  comparison with the reference. Load-time camera registration is fixed
  to arrive invisible (a visible entry activates the view client-side,
  stranding relogs outside the intro on a scripted vantage)
- balloon-family follow-ups: `remove_balloon_talk` and dialogue
  `delay_tick` scheduling (the client applies the delay itself, so
  scripts that gate via wait_tick are unaffected)

### 24. Navmesh position validation — [Partial]

The ingest builds a Recast/Detour navmesh per xblock from the client's
collision geometry (`--navmesh [xblocks]`; DotRecast pipeline ported
from the reference: doesMakeTOK entities, physics cubes, nif PhysX
props) and stores a tile/poly projection under the `navmesh` set.
`Ms2ex.Navigation` answers nearest-poly position queries with the
reference's ToNavMeshSpace transform and FindNearestPoly half extents,
and the trigger runtime's move_user refuses teleports to positions
without walkable ground (the reference's MoveToPortal ValidPosition
check) — scene-anchor portals that sit off the platform edge no longer
drop players out of the world.

Still missing: generating navmeshes for the remaining maps (the flag
currently defaults to the two verified tutorial xblocks), npc pathing
queries over the stored tiles, and auditing the generated meshes
against the reference (nif assets whose llid lookup failed leave small
gaps in walkable coverage).

### 7. Join-flow packet audit — [Partial]

`AddPortal`'s load packet (`Packets.AddPortal.bytes/1`) is now byte-correct:
dimension, action type and the minimap-visible flag were in the wrong wire
position (a stray empty field where `Dimension` belongs, `ActionType` never
read from data, `MinimapVisible` written two fields later than the client
expects), silently corrupting every field after it — invisible field-to-field
portals such as Rien's exit to Bamboo Grove could end up unusable
client-side even though the server considered them enabled. `Storage.Maps`
no longer drops disabled portals before they reach field state (they now
load with their true `enable` flag, matching the reference's load-everything,
check-enabled-at-use-time model), and the change-field handler now refuses
transition through a disabled portal instead of allowing it through on an id
match alone. `FieldAddUser` and the battle-join packet set still have not been
audited for byte-level client parity.

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
selection (accept/progress/complete), and npcs that offer a quest while
having their own talk script open the select script as a choice menu
(quest vs plain talk) with the pick routed through Continue. Basic
auto-start quests are seeded, and
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
exp and currencies are granted post-commit. Condition-counter changes from
gameplay events accumulate in memory and batch into a periodic flush (also
on demand and on stop) instead of one UPDATE per matching quest per event.
The quest manager's state stores only persisted row data (state, times,
track flag, condition counters); the quest document and condition documents
are read from the ETS cache wherever needed — no metadata is mirrored into
the manager.
Non-forfeitable quests refuse abandon, the expiration sweep drops expired
rows in one statement per owner scope and notifies the client, and
go-to-npc travel moves the character to the quest's destination map.
Event-tagged quests never start on their own: event content starts only
through a matching server event, so stale event quests no longer churn
through auto-start plus client-side expiry at login. Event-tagged quests never start on their own: event
content starts only through a matching server event, so stale event quests
no longer churn through auto-start plus client-side expiry at login.
What is still missing:

- multi-page dialogue walking within one script state (Continue index
  tracking) and script functions
  (rewards/portal/cutscene side effects inside dialogues)
- interact object lifecycle beyond the state machine: additional effects are
  invoked, drop boxes roll and `modify_code` shifts a buff's remaining
  duration; interact-driven mob spawns are not implemented
- condition sources for breakables (`breakable_object`), triggers,
  and the long-tail condition types
- selective rewards and the remaining reward-side edge cases
- Maple Navigator: audit request/response packets, remote completion, and map
  guidance flow against client behavior
- chapter rewards, job-advance hooks, and the remaining quest subcommands

### 15. Achievements — [Partial]

Achievement metadata is ingested with a condition-type index, and completed
field missions now activate exploration quests, advance milestone progress and
deliver configured item or stat-point rewards. Achievement state is owned by
`Managers.Achievement` (`achievements:<char_id>`, started at login, stopped on
disconnect): rows load once, condition events walk the storage index in
memory, new rows are inserted as they are created, and updates batch into a
periodic flush (also flushed on demand and on stop) — no per-event queries.
Trophy counts per category live on the manager and are read from it (the
character struct keeps no mirrored copy), grade completions feed back into
quest conditions (`revise_achieve_*`,
`hero_achieve`), stat-point and emote rewards are granted automatically on
rank-up while item and title rewards wait for the manual claim, and load
packets are batched per 60 entries. Riding distance is tracked from mounted
sync updates and advances `riding` conditions per 150 units travelled.

What is still missing:

- skill point rewards stay pending (no skill point API exists yet)
- condition matching limitations shared by quests, exploration, and
  achievements: `party_count` and `guild_party_count` gates are ignored;
  `target` range gates are not evaluated; `stay_cube` needs
  surface/material checks; unique collection conditions need persisted
  item/fish albums; and field-mission `progress_maps` / exploration-type
  restrictions are not enforced
- movement/time update throttling must compare the changed condition's counter
  rather than the highest counter on the quest, so an unrelated condition
  cannot suppress a five-step client update
- inventory collection counters (`item_collect` and `item_collect_revise`):
  these need a persisted collected-item map and `USER_ENV` updates; ordinary
  acquisition currently emits only `item_add` and `item_exist`
- movement and map sources now cover map, continent, exploration, running,
  crawling, falling, swimming, climbing, gliding, riding, rope, ladder, hold,
  and jump; `stay_map`, `stay_cube`, `emotiontime`, and music time conditions
  still need their own timers or field collision data
- combat sources still missing: no-damage kills, time attacks, last-hit/buff
  variants, spawner/race/event-tag kills, boss/elite/dungeon classifications,
  assist bonuses, and damage-based skill conditions require combat attribution
  that the current field combat model does not retain
- economy and item-operation sources still missing: item destroy/break/gear
  score, shop buys/sells, token currencies, enchant/merge/remake/socket/gem
  results, and limited bundles require their corresponding inventory, shop,
  currency, and upgrade systems to emit condition events
- social and world sources still missing: guild, club, marriage, mentor,
  house, banner, UGC, and profile conditions require those owning
  systems; PvP, survival, dungeon, festival, and minigame conditions require
  their event/match state and result handlers
- life-skill sources still missing: farming plots and pet actions require
  their activity and completion systems; gathering, harvesting, crafting,
  fishing and mastery grade conditions are emitted by the mastery system
- collected-item exploration progress: the trophy UI now receives the required
  `USER_ENV` response, but collected item quantities are not yet persisted or
  updated when inventory items are acquired
- exploration tasks backed by gathering, fishing, breakables, housing, pets,
  dungeons, PvP, guilds, and masteries: their systems do not yet emit the
  condition updates needed to advance field missions
- persistence tests for account-wide versus character achievements, progress,
  completion, and idempotent reward claims
- emote and skill-point rewards: emotes need an achievement-aware unlock path,
  while skill points need a trophy source in the character skill-point state
- client-side unlock rewards (beauty, coloring, and shop unlocks): their
  persistent unlock models and client update packets are not implemented
- reward types not yet delivered: `skillpoint`, `shop_weapon`, `shop_build`,
  `shop_ride`, `itemcoloring`, `beauty_makeup`, `beauty_skin`, `beauty_hair`,
  and `etc`; they need their owning unlock/persistence APIs. `itemcoloring`
  and the `beauty_*` / `shop_*` types are no-ops in the reference too
- audit every achievement reward definition against the live client metadata,
  including item ids, quantities, rarity/rank semantics, automatic versus
  manual claims, and each reward type's client update
- achievement counters in character/field profile packets and trophy rankings:
  character trophy aggregates and ranking queries/packets are not implemented
- condition sources not yet emitted by gameplay systems, including gathering,
  fishing, breakables, housing, pets, dungeons, PvP, guilds, and masteries
- achievements tied to those sources cannot progress until their owning
  gameplay systems emit condition updates
- applying the `achievements` migration and re-ingesting metadata in each
  deployment before the feature is enabled

### 20. User generated content — [Partial]

The upload pipeline is in place end to end: the client is pointed at the
`/ugc` prefix at login, announces an upload over the game session, posts the
payload to the web server, and confirms it once stored. Resources are owned
rows in `ugc_resources`, files land under the configured UGC data directory,
and the design-shop flow charges the player, stages the item and adds it to
the inventory with its descriptor persisted on `inventory_items.ugc`.

What is still missing:

- **Guild emblems and guild posters** — implemented: emblem uploads persist
  to the guild row and broadcast live to online members (`UpdateEmblem` +
  `NotifyUpdateEmblem`), and poster uploads attach to the guild's poster
  list; see item 25 for remaining guild-system gaps
- **Layout blueprints** — depend on the housing cube system; the blueprint
  block written next to the UGC descriptor is currently all zeroes
- **Free design coupons** — `use_voucher` is parsed but ignored, so the player
  is always charged the design's currency cost
- **UGC housing maps** — `LOAD_UGC_MAP` still answers with a fixed empty payload
- **UGC market** — the resale side of designed items is untouched
- **Ranking and mentor boards** — `/irrq.aspx` and `/ruq.aspx` answer with a
  well-formed but empty payload

### 21. Music performances — [Partial]

Instruments are field objects owned by the performer: improvising relays midi
notes to the map, scores play from their metadata file name or a composed MML
string, composing writes the score onto the item, and plays are debited from
the score's remaining uses. Party ensembles start every ready member on the
leader's tick. The Queenstown stage tracks one performer at a time behind the
`music_concert` field property, and Smart Push grants the paid additional
effects (auto-play extension, mount stability).

What is still missing:

- **Fishing lures** — bait item tags, `fishlure.xml`, lure-specific catch ranks
  and lure fish spawns are projected and used by fishing rolls, but the client
  bait-slot amount does not refresh from the normal inventory update packet.
  The dedicated bait-slot/autobait packet still needs client reversing; see
  item 23
- **Stage geometry** — enter/exit stage toggles between portals 802 and 803
  from a server-side membership set. The reference decides from trigger box
  101 containment, which needs trigger box geometry in the map projection
- **Performance stage extras** — the applaud and glowstick emotes (skills
  90210001 / 90210002) are parsed and dropped, and party members of the
  performer are not treated as co-performers
- **Smart Push gaps** — the `SaleAutoFishing` / `SaleAutoPlayInstrument`
  game-event content override is skipped. Two deliberate divergences: a
  purchase the player cannot afford answers with the lack-of-currency notice
  (the reference silently drops it), and entering water without the
  `SafeWaterRiding` effect throws the rider server-side (the reference leaves
  the dismount to the client)
- **Score expiry** — the reference refuses expired scores; ms2ex only checks
  remaining uses
- **Ensemble room check** — members are matched on map and channel; the
  reference also compares the instanced room id, which ms2ex has no concept of

### 25. Guild system gaps — [Partial]

Core membership flows are implemented: create/disband, invite and respond,
search (by focus and by name), applications (apply/cancel/respond), expel,
leave, leadership transfer, rank editing, notice/emblem/focus updates, member
mottos, check-in and donation (guild exp/funds/coin rewards), guild mail, and
a guild-chat alert variant gated on the `send_alert` rank permission. Presence
(login/logout, online roster, field guild-tag add/remove) and PubSub
subscribe/unsubscribe are wired through every join/leave path (create, invite
accept, application accept, expel, disband).

What is still missing or stubbed:

- **Guild buffs, personal buffs, buff upgrades** (`UseBuff` 0x58,
  `UsePersonalBuff` 0x59, `UpgradeBuff` 0x5A), **NPC upgrades** (`UpgradeNpc`
  0x6F), **gifting** (`SendGift` 0x6A, `UpdateGiftLog` 0x6D), and **capacity
  increase** (`IncreaseCapacity` 0x40) — these opcodes are now wired and
  accepted (the client no longer sees an unhandled-mode warning), but each is
  a parse-only no-op: no funds/cost deduction, no buff/npc level change, no
  gift log, no capacity change, and no reply packet. The reference project's
  own handlers for all six opcodes are equally empty (they read the payload
  and return), so there is no known request/response or cost/effect model to
  port; only the metadata (`guild.xml` buff/npc cost, level and duration
  tables) and default buff seeding at guild creation
  (`Types.GuildBuff.default_buffs/0`, ids 1-4 and 10001-10005 at level 1)
  exist today. Building real behavior here means designing new mechanics
  rather than matching a known implementation
- **Guild arcade / raids** (`StartArcade` 0x60, `EnterArcade` 0x61) and guild
  events (`CreateGuildEvent` 0x70, `StartGuildEvent` 0x71, `JoinGuildEvent`
  0x75) — entirely unimplemented; no packet handling, no room/instance model
- **Guild house** — `EnterHouse` teleports to the configured house map and
  `UpgradeHouseRank`/`UpgradeHouseTheme` persist and broadcast the change, but
  the house map itself has no content: it depends on the housing/UGC cube
  system (item 19), which is still open
- **`ListApplications`/`ListAppliedGuilds` wire format is unverified** — the
  reference project's own request handler for this opcode is an empty stub
  (never exercised against a real client), so its packet layout could not be
  fully confirmed; the current implementation was derived from repeated
  client crash analysis rather than a known-good source. Treat this as the
  least-trusted packet in the guild system if list-of-applications bugs
  resurface
- guild leveling (experience accumulation via check-in/donation) has not been
  verified end-to-end against rank-up thresholds and rewards
- no audit yet of `list_guilds`/search results reflecting "already applied"
  state client-side (the Apply button does not currently indicate a pending
  application)

---

## P4 — Architecture

### 15. Character-owned inventory — [Partial]

The ownership model is in place: `Ms2ex.Managers.Inventory`
(`inventories:<char_id>`, like the quest manager) owns every item row and tab
size of a character in memory — lean rows without metadata documents (see
item 18) — started at login and stopped on disconnect. `Context.Inventory`
delegates reads and mutations (add/stack, consume, cross-stack consumption,
delete, generic updates, swap, sort, tab expansion) and slot allocation to
the manager when it is alive, falling back to the direct DB path otherwise
(login-server flows, tests); write-through keeps rows and memory coherent.
Equip transitions already route their item moves through the manager, and
the character's cached equip list is refreshed from it.

What is still missing:

- quest completion still wraps turn-in consumption in a caller-side
  `Repo.transaction`; with the manager alive, item writes no longer join
  that transaction, so completion should be restructured into in-process
  ordering inside the manager (consume turn-ins + grant item rewards as one
  manager call) instead of cross-table DB atomicity
- the character manager's cached equip list is a second copy of the equip
  subset — it could be dropped in favor of reading the inventory owner's
  state once field serialization tolerates it
- shops / trades / storage / mail item flows are not implemented yet and
  should route through the manager as they arrive
- trigger points for finishing this: item-flow features landing (shops,
  trades, storage, mail), `item_exist` checks feeling heavy, or growth
  beyond a single node
- explicitly rejected: read-caches layered over the DB — two sources of
  truth with the classic invalidation bugs, and none of the ownership
  benefits

### 18. Metadata-free manager state — [Partial]

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

- Trigger runtime: implemented the `npc_detected` condition (a story
  npc's spawn point standing inside a trigger box — drives scripted
  arrivals such as an npc that walked off via `move_npc` reaching its
  destination) and the `create_item` action (a map's item spawn point
  drops a fixed-position, unowned field item, either a named item id or
  rolled from the spawn point's individual/global drop box). The ingest
  now projects `EventSpawnPointItem` entities (`item_spawns` per map),
  previously parsed but never written to any doc. Fixed the berserker
  chapter's "pick up an item from the ground" quest step, which had no
  item to pick up. Also implemented `set_time_scale` (cinematic
  bullet-time/slow-mo beats), which needed a new `TimeScale` send opcode
  — it was never registered at all
- Guild System: guild creation/disbanding, invites and responses, search and
  applications, role/permission configurations (Master, Jr. Master, Veteran,
  Member, Recruit), member mottos, daily check-in (player exp, guild exp,
  funds, and guild coin rewards), donations, leadership transfer, notices,
  UGC emblems and poster uploads, guild chat routing (`USER_CHAT` `:guild`),
  and online/offline presence notifications across channels and maps via
  `GuildServer` and `GuildManager`
- Guild System stabilization pass: fixed a client-crashing malformed
  `Error`/`Guild.Load`/`ListGuilds`/`GuildInvite` wire format (each missing
  fields relative to the client's expected layout), a double guild-topic
  PubSub subscribe that duplicated every guild broadcast (login/logout,
  notice, emblem changes), missing subscribe calls on guild creation, invite
  acceptance and application acceptance (members/leaders not seeing each
  other join without relogging), missing unsubscribe on leave/expel/disband
  (ex-members still receiving guild chat), a stale roster snapshot on login
  showing the character as offline to themselves, live guild-member profile
  picture and emblem updates (previously required a relogin), guild
  nameplate tag add/remove on the field via `AddTag`/`RemoveTag` (previously
  never implemented, so the tag persisted after leaving/being kicked), a
  wrong notification on application acceptance (showed the invite-flow text
  instead of the application-flow text), a misleading "Application not
  found" message on a duplicate apply (now checks for an existing pending
  application first), and implemented guild mail (`SendMail`) and the guild
  chat alert variant (`guild_notice`/`guild_notice_noprefix`), both
  previously unhandled. See item 25 for what's still open
- Mail System & Reward Delivery Fallbacks: player-to-player mail, system mail
  with item/currency attachments and XML template argument formatting, account-wide
  mail binding at login, batched inbox loading, single/bulk reading, attachment
  collection with per-tab inventory validation, and safe deletion. When player
  inventories are full, reward items from achievement claims, item box opens,
  quest completions, field missions, fishing spots, and mastery gathering/crafting
  automatically overflow into system mail deliveries instead of dropping or failing.
  Condition event emission for `:send_mail` advances corresponding achievements

### Trigger tutorial systems (character tutorial PR series)

- Liftable quest props: ingest projection (all fields), field-enter batch
  with quest masks AND the react flag (the quest-effect glow — was
  hardcoded off in the batch, so props only glowed after pickup+place),
  pickup/install via LIFTABLE + REQUEST_CUBE, placed
  prop rendering, item_move condition wiring — the squire-carry quest
  works end to end
- Script npc emotes (`set_npc_emotion_loop` + one-shot
  `set_npc_emotion_sequence`) and dialogue (`set_dialogue` balloons +
  cinematic talks) via the new `animation` ingest set (anikeytext per
  model, sequence name -> id); player emote sequences too
  (`set_pc_emotion_sequence` → Trigger ui EmotionSequence frame with the
  comma-split sequence list)
- Story-npc walks play real locomotion instead of sliding: patrol legs
  resolve each waypoint's approach animation against the npc model's
  animation table (fallback Walk_A → Run_A — models like the striker
  champion whose anikey table lacks Walk_A run instead of sliding), the
  control packet streams the Walk actor state while the patrol moves the
  npc (the client keys the locomotion animation on this state), and the
  npc returns to its model's Idle_A when the path ends. A model with no
  walk/run sequence at all stays put with a warning instead of drifting
  in its idle pose
- The knight main quest chain (52000116_qd, "A Natural Hero") completes:
  its closing beat fires `set_achievement(box, "trigger", "jordy")` —
  now implemented as the reference's ConditionUpdate (quest +
  achievement condition event for players in the box), which is the
  quest's only completion condition. The beat's `show_caption` named-title
  card broadcasts the Cinematic Caption packet, and `reset_camera` reads
  the script's `interpolation_time` (was reading a positional arg,
  always sending 0.0)
- String-code condition matching (shared by quests and achievements):
  conditions configured with code strings (trigger names, emote keys,
  npc races) now match the pushed event's code string — previously the
  string was ignored and any event of the type counted. This fixes a
  mass unlock where one script's `set_achievement("jordy")` event
  advanced all 106 trigger-coded achievements (none of which are coded
  "jordy"), and makes the 57 emotion quest conditions require the
  actual emote key the client sends (reference: aniKey → codeString)
- Speech balloons actually render now: `set_dialogue` reads its
  positional args (type, spawn point, script, seconds) instead of named
  keys the data never carries — every dialogue fell through to an empty
  player-anchored balloon. `add_balloon_talk` (named args: msg,
  duration, spawn_point_id, delay_tick) sends the unflagged balloon
  variant, and `play_system_sound_in_box` fires the new
  PLAY_SYSTEM_SOUND packet field-wide or per player inside the boxes
- npc story walks (`move_npc` patrol attachment, staying at the last
  waypoint) and player emotion loops (`set_pc_emotion_loop` → Trigger ui
  EmotionLoop frame)
- Trigger scripts run on every map that ships them (whitelist removed);
  unimplemented actions warn in the server log so coverage gaps surface
  per map
- Quest/talk npc flow mirrors the dialogue handler: npcs offering a
  quest with a talk script open the select script as a choice menu
  (quest vs plain talk) with the pick routed through Continue
- quest_user_detected distinguishes the wanted states (1 started,
  2 completable, 3 completed) — the squire-carry beat advances on the
  right state instead of stalling on the pickup hint
- Quest manager state carries only persisted row data (state, times,
  track, condition counters); quest and condition documents resolve
  from the ETS cache at use time, and the virtual metadata field is
  dropped from CharacterQuest — fixes same-session turn-in crashes
- npc_spawns is keyed by the map's spawn point id (the id scripts use),
  and spawned npcs carry it — spawn-id-targeted actions (emotions,
  npc balloons) land on the right npc
- Placed liftables expire item_lifetime + finish_time after placement
  (RemoveCube + LIFTABLE Remove) — the dropped prop no longer lingers
  next to the scripted lying npc
- Scripted portal moves send USER_MOVE_BY_PORTAL with the 25-unit
  drop-in offset and float rotation — the post-quest scene-anchor
  teleport no longer drops the player through the ground
- Trigger Load registers cameras invisible (a visible entry activated
  the view client-side, stranding relogs on a scripted vantage)
- Int-list trigger args expand inclusive ranges (`5001-5025`) — the
  tutorial arrow trails light every effect
- Unhandled trigger actions log at warning level, so per-map coverage
  gaps surface during play
- Guide summary hints held during cutscenes and scripted path moves,
  flushed exactly when the player regains control
- Follow-dummy facing: the dummy's rotation derives from its movement
  direction (yaw = atan2(vx, -vy), the reference's ground-plane LookTo)
  and streams in the control entry, so the carried player faces where
  the scripted path is heading
- Cinematic UI transitions: set_cinematic_ui types 3–6 broadcast the
  View packet (letterbox / fade / horizontal / vertical wipes) and type
  9 the opening black screen — the letterbox backing is what cinematic
  dialog bubbles render over
- Follow-dummy movement: 3D patrol stepping with streamed velocity and
  approach-animation resolution
- Bind-on-loot items are character-bound when added to the inventory
  (starter weapons no longer prompt on equip)
- Fresh characters receive client-default key binds and hot bars seeded
  with learned active skills (reference LoadKeyTable/UpdateHotbarSkills)
- Spawn-load race fix: trigger machines start only after every spawn
  point doc is registered; script-controlled maps seed their full cast
  from the scripts alone
- Shallow-water exclusion for fishing tiles: the ingest now also projects the
  grid-aligned collision boxes (`GeneratePhysX` cubes are ground, whiteboxes
  are not), so a fluid cube is fishable only when nothing occupies the cell
  above it and its own cell holds no ground collider — the reference's
  `IsSurface && !IsShallow` test, without needing the PhysX/NIF mesh pipeline.
  Boxes that do not fit their own cell only mark occupancy, matching the
  reference's unaligned entities
- Auto-fishing: `BuffEventType` is projected onto additional effects, so the
  Smart Push auto-fish buff is detected — it suppresses the fight minigame and
  flags catches for the client. Smart Push `autoInteraction` (bulk gathering)
  now harvests a recipe repeatedly at the player's feet until the node's
  success rate decays to zero, and interact objects apply their
  `modify_code` / `modify_time` buff-duration change. A landed fish grants
  fishing exp (the reference declares the exp type but never awards it)

- Fishing: fluid cubes are projected per map by the ingest (the surface cube
  of every column deeper than one block), so casting a rod finds the water in
  front of the player, spawns the bobber guide object and hands the tiles to
  the client. Casting picks a fish from the map's spot and fish boxes
  (habitat and spot-mastery filtered, weighted), arms the bite timer from
  `fisherBoreDuration` minus the rod's reduction, and resolving the bite rolls
  the size, updates the persisted fish album, broadcasts prize catches, rolls
  the spot's drop boxes and awards fishing mastery. `fish.xml` (fishes, spots,
  fish boxes) and `fishingrod.xml` are new ingest projections
- Interact objects: their drop boxes now roll and land at the object (global
  and individual boxes, drop height), invoke effects apply as buffs, and
  telescopes grant their exploration exp once per object with the discovered
  set persisted and replayed to the client

- Life skills (mastery): mastery values, gathering counts and claimed grade
  rewards live on the character process and batch-flush to the row, so a
  gathering spree writes no UPDATE per node. Gathering nodes resolve through
  the mastery recipe table with the client's success-rate falloff (reward
  items drop on the node, gathering exp and mastery are awarded, and the
  grade-differential cutoff stops mastery for recipes far below the player's
  grade), crafting consumes ingredients plus meso and hands out the crafted
  items with manufacturing exp, grade reward boxes can be claimed once, and
  stopping a music score awards performance mastery scaled by play time plus
  `musicMastery1-4` exp. The mastery block in the character packet carries the
  real values, and the `masteryreceipe.xml`, `mastery.xml`,
  `masterydifferentialfactor.xml` and `commonexp.xml` tables are projected by
  the ingest


- Quest condition batching: quest condition counters accumulate in memory
  in the quest manager and mark quests dirty for a periodic flush (also
  flushed on demand and on stop) — ordinary gameplay events (kills,
  movement, pickups) no longer write one UPDATE per matching quest per
  event. Quest transitions that own their persistence (start, complete,
  abandon, expire) still write through. Application stop flushes every
  live deferred manager before the supervision tree shuts down
  (`Application.prep_stop/2` stops the ad-hoc per-character managers, whose
  terminate callback writes the pending batch)
- Auto-start gating: quests carrying an event tag never start on their own
  (event content starts only through a matching server event, and stale
  event quests would otherwise be auto-started at login and immediately
  expired by the client in an insert/delete churn). The client expiration
  sweep now drops expired rows in one DELETE per owner scope instead of
  one per quest
- Equipped items are no longer mirrored on the character struct: field
  appearance, character info, stat rebuilds and conflict resolution read
  the inventory manager at point of use, and `Context.ItemStats` takes
  the equipped items as an argument so contexts stay free of manager
  reads (same treatment as the mirrored trophy counts before them)
- Achievement manager: `Managers.Achievement`
  (`achievements:<char_id>`, like the quest manager) owns every achievement
  row in memory — condition events walk the metadata index without touching
  the database, new rows insert on creation, updates batch into a periodic
  flush (and a flush on disconnect). Trophy counts live on the manager and
  are read from it — the character struct keeps no mirrored copy — grade
  completions notify quest conditions, stat
  point and emote rewards apply on rank-up while item and title rewards wait
  for the claim, and `Context.Achievements` shrank to pure persistence.
  Meta-trophies that track other achievements (`revise_achieve_*`,
  `hero_achieve`) gate on the completing achievement id and reached grade —
  without the gate a single map-visit trophy cascaded into dozens of
  meta-trophy unlocks at login
- Character-owned inventory manager: `Managers.Inventory`
  (`inventories:<char_id>`, like the quest manager) owns every item row and
  tab size of a character in memory — reads from memory, write-through
  mutations, in-memory slot allocation; `Context.Inventory` delegates to it
  when alive and falls back to the database otherwise; started at login,
  stopped on disconnect (item 15 continues from here)
- Item locks: the inventory lock-mode flow (stage / unstage / commit on
  recv 0x88) with `is_locked` persisted via a new migration, and the 72-hour
  unlock window stamped from the server constants on unlock
- Equip flow fixes found in testing: the displaced item's bag Add is sent
  after the equipped item's Remove (the swapped order made the client hide
  the displaced item and later duplicate entries), and the sort/expand
  handlers resolve the wire tab integer to the tab atom (sorting wiped the
  tab client-side)
- Seed test bag: mounts, unequipped gear, spare weapons, consumables and
  misc stacks for both seeded characters; seeds equip items by explicit slot
- Dead session returns removed from the game handlers
- Buff persistence: buffs whose effect metadata does not set
  `remove_on_logout` are stored in `character_buffs` with an absolute expiry
  and re-applied for their remaining duration on the next field the character
  enters, so long-running effects survive map changes, channel switches and
  relogs. Expiry is wall-clock because the tick base is per-VM

- User generated content pipeline: UGC send packets (upload acknowledgement,
  path update, profile picture, item/mount/furnishing updates, banner list),
  login and game handlers, an owned `ugc_resources` table, and a Phoenix web
  surface under `/ugc` (`/urq.aspx` upload plus the profile, item, item icon,
  banner, guild mark and blueprint fetch routes) with path-traversal, size and
  ownership guards. Design-shop items are charged, staged and added to the
  inventory with their descriptor persisted and serialized alongside the item.
  Field banners persist reservations, upload their artwork, restore schedules
  on relog, and activate at the scheduled UTC hour

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
