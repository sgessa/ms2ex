# Changelog

Completed work, newest first. Open items live in [ROADMAP.md](ROADMAP.md).


- Cube-skill zones tick at the constants table's cube skill cadence
  (100ms) instead of a hardcoded 1s, matching the reference: the thin
  hit volumes (70 units tall) sampled once a second missed whenever a
  player was mid-jump or bobbing in water — the slow lanes crossing the
  cave's water pools never registered a hit between samples.- Skill zones only apply the effects their attack actually lists: the
  zone tick used to grant every player the zone skill's same-id effect
  unconditionally, so the falling rocks (whose attack lists no effects)
  handed out a stray, logout-persisting "water fun" buff. The lane
  buffs, which the attacks do list, are unaffected.- Trigger skill zones (set_skill) now own a server-side attack: enable
  spawns a fire-count-limited zone announced to clients, each fire applies
  the zone skill's attack damage to players standing inside (max-health
  share, constant value — the shared stats path, death included) plus its
  effect as a buff, and broadcasts a tile damage record; disable removes
  every active zone for the trigger id. This was the actual falling-rock
  gap: the rocks of the tutorial chase are trigger skills, not map cubes,
  so the earlier cube-zone damage work never reached them — set_skill only
  rendered zones client-side. Unlike cube cells (which sit one block below
  the surface they cover), trigger anchors sit at the ground plane and
  their hit volume starts right there.- Cube-skill zone attacks now deal their skill damage: the projected
  attack carries the full damage rule (hit count, constant-damage flag,
  damage-by-target-max-hp share) and the zone tick applies it before the
  buff — max-health share, then constant value — reducing the player's
  health through the shared stats path (regen deferral and death
  included) and broadcasting a tile damage record with the push
  direction. The tutorial chase's falling rocks (skill 70000099) hit for
  10% of max health per tick; their rate/value fields are genuinely zero
  in the data — the damage was hiding in the max-health share.- Cube-skill zone hit volumes match the skill's attack prism: the zone's
  range (type, distance, height, width, range adds, apply target) is
  projected with the skill set and resolved from skill metadata at zone
  load; box ranges form a rectangle centered on the cube cell, cylinders
  a circle of radius = distance, both raised one block so the base sits
  above the cell top. The earlier fixed-radius circle applied the Cave
  Depths lane buffs when standing near but not on the lane tiles.
- Cube-skill zones (boost/slow lanes, hazard water) are projected and
  ticked: the ingest keeps `Ms2CubeSkill` entities even when the cube is
  a fluid — the fluid case used to swallow them — and the field ticks
  every second, applying the zone skill's effect as a buff to players
  standing inside. Cave Depths' (52000066, the Berserker masked-figure
  chase) lanes now grant "Speed Up" (+300% movement for 2s, refreshed
  while on the lane) and their blue slow-lane counterpart, matching the
  reference's cube-skill handling.
- Map-placed region skills are projected and reach clients: the ingest
  carries each map's `region_skills` (skill id, level, fire interval,
  fixed position — boost lanes, zone hazards; cube-placed skills are
  excluded), the field allocates every zone a stable source id at init,
  and entering players receive the zone frame so the client executes the
  effect while they stand inside. Kerning Interchange's launch lane
  (skill 70000018) now works, unblocking the Masked Boy chase in the
  main story.
- Trigger actions `set_actor` and `set_ladder` are implemented: actor
  figure visibility with its animation sequence, and ladder visibility
  with the climb-in animation flag and fade delay. Both broadcast the
  trigger-object update by id (actors and ladders are not projected
  yet). Together with `select_camera`, `set_agent` and
  `remove_cinematic_talk` this closes the unimplemented-action warnings
  on the class-intro and interchange scripted maps.
- Trigger condition `object_interacted` is implemented: fires when an
  interact object (matched by its table id) sits in the wanted state (0
  normal, 1 reactable, 2 hidden). Gates the Blackstar Junkyard's car ride
  (63000023 `gototria01`): the script arms the car via set_interact_object
  and waits for the board to flip it back to normal, then runs the
  cinematic drive and move_user to Lith Harbor — the whole gototria01
  script is now fully covered by the runtime.
- Trigger actions `select_camera`, `set_agent` and
  `remove_cinematic_talk` are implemented: camera vantage on/off for the
  map's registered cameras (enable=false releases the view), agent figure
  visibility by trigger id (agents are not projected yet — the update
  reaches the client by id alone), and clearing the cinematic dialog
  bubble at the end of a talk beat. Surfaces during the class-intro
  scripted chains (e.g. 63000026_cs).
- Scripted maps no longer blanket-defer npc spawns to their trigger
  scripts: event spawn points (`is_event`) stay script-summoned one-shots,
  but every plain spawn — quest npcs and roaming mobs — loads per its
  `on_field_create` flag exactly as on unscripted maps. The old map-wide
  gate silently removed 525 story-npc spawn points across 275 scripted
  maps — e.g. the Striker tutorial's Bravo in the Underground Passage
  (63000017), which no script ever summons, dead-ending the "Into the
  Underground Passage" turn-in with no npc to talk to.
- Instanced maps: the instance-field table is now projected
  (`server.instancefield.xml`) and `solo` maps (every tutorial and quest
  instance) allocate a private field per entry instead of dropping
  everyone into one shared map — fixes players colliding in the tutorial
  and breaking each other's progression. The instance id is allocated
  once per transition and carried on the character, and the field's
  PubSub topic carries it too, so instances never hear each other's
  packets; scripted cross-map moves stop the solo field they vacated.
  A relog mid-instanced-map lands in a fresh instance of the same stage
  (reference `SpawnPlayer` semantics). Ingest grew an
  `--probe-instance-field` dump of the raw table.
- Field manager reorganization: moved the field process API, PubSub
  broadcast topology and the enter/leave/change_field lifecycle out of
  `Context.Field` (deleted) onto `Managers.Field`, matching the
  contexts-persist/managers-own-state rule; raw message tuples at call
  sites became named API functions (`add_effect_buff`, `inflict_dmg`,
  `pickup_liftable`, `user_position`, ...). Extracted the banner slot
  logic into `Managers.Field.Banner`, split `Managers.Field.Trigger`
  into runtime + `Trigger.Conditions` + `Trigger.Actions`, moved the
  trigger argument coercion into a new `Ms2ex.Helpers.TriggerArgs`
  (seeding the `helpers/` namespace from the code-organization guide),
  and split npc movement math into `Field.Npc.Patrol`. Dropped the dead
  `add_object`/`cancel_battle_stance` API. No behavior change; 365 tests
  green.

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
  — it was never registered at all, and `set_event_ui` (the ingest now
  resolves that splitter action into round/script/countdown targets;
  a new `MassiveEvent` send opcode drives the overlays, scoped to
  trigger boxes with `!` negation and box 0 as "everyone"). Re-ingest
  with `--drop-data` also cleared stale trigger docs that lingered
  under doubled-prefix keys from an older ingest version
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
  now implemented as a server-side condition update (quest +
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
  actual emote key the client sends (aniKey → codeString)
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
  direction (yaw = atan2(vx, -vy), the ground-plane look-at convention)
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
  with learned active skills (client LoadKeyTable/UpdateHotbarSkills behavior)
- Spawn-load race fix: trigger machines start only after every spawn
  point doc is registered; script-controlled maps seed their full cast
  from the scripts alone
- Shallow-water exclusion for fishing tiles: the ingest now also projects the
  grid-aligned collision boxes (`GeneratePhysX` cubes are ground, whiteboxes
  are not), so a fluid cube is fishable only when nothing occupies the cell
  above it and its own cell holds no ground collider — the client's
  `IsSurface && !IsShallow` test, without needing the PhysX/NIF mesh pipeline.
  Boxes that do not fit their own cell only mark occupancy, matching the
  client's unaligned-entity behavior
- Auto-fishing: `BuffEventType` is projected onto additional effects, so the
  Smart Push auto-fish buff is detected — it suppresses the fight minigame and
  flags catches for the client. Smart Push `autoInteraction` (bulk gathering)
  now harvests a recipe repeatedly at the player's feet until the node's
  success rate decays to zero, and interact objects apply their
  `modify_code` / `modify_time` buff-duration change. A landed fish grants
  fishing exp (the exp type exists in the data but was never awarded before)

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
  conflicts and unequips in the established order (vacated slot preferred,
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
