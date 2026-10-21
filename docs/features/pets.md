# Pets

Status: partially implemented. Pet metadata, the pet exp table and the
wild-pet spawn roll fields are ingested; pet items serialize their info
block; the summon flow works (handlers, manager, field actor, collection).
Still open: the pet's item bag, wild pets & taming, and the config
persistence noted below.

## What a pet is

A pet is an item (`item_type: pet`, `:pets` tab) that can be summoned into
the field as an NPC-like actor. The item carries per-item state:

- name, exp, level, evolve points, remaining free renames
- a potion auto-use config (list of `{index, threshold, item_id}`)
- a loot filter config (8 category flags + rarity + enabled)
- the pet's item bag contents (only for `type: 0` pets — pets with slots)

Pet metadata (keyed by item id, `6001xxx`) supplies the rest:

- `type` (0 = has an item bag), `npc_id` (field actor appearance), `item_slots`
- `skill` (id + level) and `additional_effect` id/level pairs the pet applies
- movement distances: `warp`, `trace`, `battle_trace`
- animation timings: `idle`, `bore`, `summon_cast`, `tired`, `skill`
- `option_level` / `option_factor` (stat reroll), `enable_pet_extraction`,
  `taming_ai_presets`

Wild pets are spawned by mob spawn rolls (`pet_spawn_rate` on a spawn
region, with a per-map `npc_id -> pet_id` roll table and a `pet_population`
cap). They are tamed by pet-taming skill damage; owned pets are summoned
from the `:pets` tab.

## Ingest

Projected (read via `Ms2ex.Storage.Pets` / `Ms2ex.Storage.Tables.PetExp`):

1. **`pet:<item id>` set** — one doc per pet row: `id`, `name`, `type`,
   `npc_id`, `item_slots`, `enable_extraction`, `option_level`,
   `option_factor`, `ai_presets` (list), `skill` (`id`/`level`, nil when
   none), `effects` (`id`/`level` pairs), `distances` (`warp`, `trace`,
   `battle_trace`), `times` (`idle`, `bore`, `summon_cast`, `tired`,
   `skill`). Pets without a pet xml entry fall back to property-row
   distances and default timings (`idle: 70000, bore: 120000,
   skill: 13000, tired: 10000, summon_cast: 700`).
2. **Item docs** carry `property.pet_id` (0 for non-pets) — the npc-facing
   link the summon flow resolves.
3. **Map docs** carry the wild-pet roll on each `mob_spawn`:
   `pet_spawn_rate` (roll chance per spawn cycle), `pet_population` (concurrent
   cap), `pet_ids` (aligned with `npc_ids`/`weights`; 0 where that mob has no
   pet — the pet pool inherits its mob's weight).
4. **`table:petexp.xml`** — `table.levels[level][rarity]` → exp to next
   level (rarity 1 = normal .. 6 = artifact; 0 at the level cap).
5. Constants (`taming_pet_max_point`, `pet_run_speed`, `pet_pick_distance`,
   ...) already flow through the generic `table:server.constants.xml` doc —
   read via `Ms2ex.Storage.Tables.Constants.get/1`.

## Item serialization

Done. Pet items (`inventory_tab == :pets`) write their info block in the
`put_template` chain (after the ugc branch, before music/badge):
name (ustring, utf16), exp (long), evolve points (int), level (int),
has-items (bool — always false until pets carry a bag). State lives in
`item.data.pet` and reads through `Ms2ex.Types.ItemPet.get/1`, which falls
back to defaults (`name: "", exp: 0, level: 1, rename_remaining: 1`) for
items without pet state.

## Packets

Missing from `Ops.Send`/`Ops.Recv`: `FIELD_ADD_PET` (0x5B),
`FIELD_REMOVE_PET` (0x5C), `SYNC_PET_TAMING_POINT` (0x5D), `RESPONSE_PET`
(0xCE), `PET_INVENTORY` (0xD0). Recv: `REQUEST_PET` (0x79),
`REQUEST_PET_INVENTORY` (0x7A).

### RESPONSE_PET (0xCE) — command byte first

| cmd | name | layout after command |
| --- | --- | --- |
| 0 | summon | int owner_obj_id, int pet_obj_id, bool(true), int item_id, long item_uid, int rarity, item block |
| 1 | un_summon | int owner_obj_id, long item_uid |
| 2 | unknown | int owner_obj_id |
| 4 | rename | int owner_obj_id, ustring name, long exp, int(0), int level, short rename_remaining |
| 5 | potion_config | int owner_obj_id, byte count, [int index, float threshold, int item_id]×count |
| 6 | loot_config | int owner_obj_id, 8×bool (mesos, merets, other, currency, equipment, consumable, gemstone, dropped), int rarity, bool enabled |
| 7 | load_collection | int count, [int pet_id, short rarity]×count |
| 8 | add_collection | int pet_id, short rarity |
| 9 | load | int owner_obj_id, profile block (ustring name, long exp, int(0), int level, short rename_remaining), byte count + potion configs, loot config |
| 10 | fusion | int owner_obj_id, long exp, long item_uid |
| 11 | level_up | int owner_obj_id, int level, long item_uid |
| 12 | fusion_count | int count |
| 15 | is_summoned | bool |
| 16 | pet_info | int owner_obj_id, int item_id, long item_uid, int rarity, item block |
| 17 | evolve | int owner_obj_id, long item_uid, byte rarity, item block |
| 18 | evolve_points | int owner_obj_id, int evolve_points, long item_uid |
| 19 | error | int error code |
| 20 | master_snare | int item_id |
| 21 | unknown | int owner_obj_id, bool(true), int item_id, long item_uid, int rarity, item block |

### PET_INVENTORY (0xD0) — command byte first

| cmd | name | layout after command |
| --- | --- | --- |
| 0 | add | int item_id, long uid, short slot, int rarity, ustring(""), item block |
| 1 | remove | long uid |
| 2 | update | long uid, int amount |
| 3 | move | long dst_uid, short src_slot, long src_uid, short dst_slot |
| 4 | load | short count, [int item_id, long uid, short slot, int rarity, item block]×count |
| 6 | reset | (nothing) |

### Field packets

- `FIELD_ADD_PET` (0x5B): int obj_id, int skin_id (badge pet-skin or npc id),
  int npc_id, coord position, coord rotation, float scale, int owner_obj_id,
  npc stats block, long item_uid, byte(0), short npc level, short taming_rank,
  int(0), ustring pet name
- `FIELD_REMOVE_PET` (0x5C): int obj_id
- proxy object add-pet (command 9): int obj_id, int skin_id, int npc_id,
  bool is_dead, coord position; remove-pet (command 10): int obj_id
- `SYNC_PET_TAMING_POINT` (0x5D): int pet_obj_id, int caster_obj_id,
  int taming_points

## REQUEST_PET (0x79) — commands

| cmd | name | payload |
| --- | --- | --- |
| 0 | summon | long pet item uid |
| 1 | un_summon | long pet item uid |
| 3 | switch | long pet item uid (unsummon current, summon new) |
| 4 | rename | ustring name |
| 5 | update_potion_config | byte count, [int index, float threshold, int item_id]×count |
| 6 | update_loot_config | 8×bool, int rarity, bool enabled |
| 12 | fusion | long uid, short count, [long fodder uid, int count]× — TODO, unimplemented |
| 15 | attack | bool — TODO, unimplemented |
| 16 | unknown | long, long |
| 17 | evolve | long uid — TODO, unimplemented |
| 18 | evolve_points | long uid, short count, [long fodder uid]× — TODO, unimplemented |

## REQUEST_PET_INVENTORY (0x7A) — commands

| cmd | name | payload |
| --- | --- | --- |
| 0 | add | long item uid, short slot, int amount (deposit into pet bag) |
| 1 | remove | long item uid, short slot, int amount (withdraw) |
| 3 | move | long item uid, short dst_slot |
| 7 | load | (nothing) — client asks for the bag contents |

## Runtime behavior

Summon lifecycle:

1. Client sends summon with a pet item uid. The server resolves the item in
   the `:pets` tab, spawns the field pet (npc metadata via the item's
   `pet_id`, navmesh crowd-agent for movement, global object id because the
   pet follows the player across maps), and broadcasts `FIELD_ADD_PET` +
   proxy add.
2. The summoned pet applies its metadata `additional_effect`s and its
   collection entry is recorded (pet id -> highest rarity seen; only sent
   when it increases) and `RESPONSE_PET load` goes to the owner with
   profile + configs.
3. Despawn (un_summon, switch, logout, map change): persist config + bag
   contents, broadcast `FIELD_REMOVE_PET` + proxy remove.

Pet bag: deposits remove from the player inventory and add to the pet bag
(stacking where possible, error strings
`s_pet_inventory_not_sendin*`), withdrawals reverse it, moves swap within
the bag. Pet items themselves cannot be deposited into a bag
(`s_pet_inventory_not_sendin_petitem`). All of it persists keyed by the pet
item uid.

Wild pets & taming:

1. A mob spawn roll (`pet_spawn_rate`, capped by `pet_population`) may spawn
   a wild pet from the map's `pet_ids` roll table. A wild pet rolls a
   taming rank 1..100 (green < 70, yellow < 95, red >= 95).
2. Pet-taming skill attacks add taming points (capped by
   `TamingPetMaxPoint`); points decay 100/s and sync via
   `SYNC_PET_TAMING_POINT`. Hitting a pet another player is taming is
   rejected.
3. At the cap (trap attacks can fail), or on a forced-capture trap, the wild
   pet dies and drops as a pet field item with rarity `rank/25 + 1` and
   rolled stats (`option_level`/`option_factor`).

Pet skin: an equipped `:pet_skin` badge overrides the field skin id; badge
changes push the new skin to the live pet.

## Server placement (ms2ex)

- `Ms2ex.Managers.Pet` — session-scoped manager owning the summoned pet:
  bag `ItemCollection`, potion/loot config, collection unlock; persists
  through a context; started on summon, stopped on despawn.
- `Ms2ex.Managers.Field` — field-pet actor registration (spawn/despawn/
  serialization of the field packets), wild spawn roll in the mob spawn
  cycle (TODO already at `managers/field/npc.ex`).
- `Ms2ex.GameHandlers.Pet` / `PetInventory` — recv handlers + `Spec`
  layouts for `REQUEST_PET` / `REQUEST_PET_INVENTORY`.
- `Ms2ex.Schema.Item` — pet struct (name, exp, level, evolve points,
  rename remaining, config, bag) + persistence.

## Staging

1. ~~Ingest: pet metadata set, item `pet_id`, map pet-spawn fields, pet exp
   table, constants~~ — done.
2. ~~Item schema + inventory serialization of the pet block~~ — done.
3. ~~Summon/despawn flow: handlers, pet manager, field packets, collection~~ —
   done. `Ms2ex.Managers.Pet` (named `:pets:<character id>`) owns the
   summoned pet from `REQUEST_PET` summon/un_summon/switch/rename/config
   commands; the field registers the actor (`state.pets`), serializes it to
   joiners, and broadcasts its removal when the owner leaves. The pet
   re-anchors across map changes through an async cast from the field's
   character-add path (the field process must never wait on the pet
   manager, which calls back into it). Collection unlocks persist on
   `characters.pet_collection` (pet id -> rarity, only rarity increases
   update it) and load at login. Config (potion thresholds, loot filter)
   is held in memory only — no persistence yet.
4. Pet bag: pet inventory handlers + persistence. (~2–3 h)
5. Wild pets & taming: spawn rolls, taming damage, capture drop. (~4 h)
6. ~~Pet movement~~ — done. The pet follows its owner through
   `Managers.Field.Npc.Battle.follow/5`, per the pet AI script
   (`AI/Pet/AI_DefaultPetTaming.xml` preset `default`, inspectable with the
   ingest's `--probe-ai`) plus the retail separation warp: navmesh chase in
   the 100–1000 unit band; stand when nearer than 100 (the script plays
   idle flicks there); stand — not chase — between 1000 and the pet's
   metadata warp distance (1200 for current pets); **warp to the owner
   (floor-snapped) beyond the warp distance**. The warp is what makes the
   pet keep up across platforms and unwalkable ground. Controls serialize
   on change only, riding the same dirty-flag stream npcs use.

## Open gaps

- Fusion, evolve, and evolve-points commands are read but unimplemented
  (no server behavior; fodder items are consumed by no logic).
- The pet's auto-pickup of drops and auto-potion use are modeled only as
  synced config — no field logic consumes the loot config or potion
  thresholds yet.
- Pet feeding (pet food items raising exp) has no handler.
- The `attack` command (15) is a stub.
