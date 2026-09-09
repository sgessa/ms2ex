# Monster drops

Status: death, hit, corpse, smart-drop, binding, map gating and trade state are
all aligned. This file keeps the full drop semantics for future work.

## Drop semantics

Two independent drop families, both resolved from the same box-id metadata and
both consumed as `FieldAddItem` drops:

- **Global boxes** (`global_drop_box_ids`): a box id references a set of item
  *groups*; each group gates on **NPC level** (`minLevel`/`maxLevel`), map type
  and continent, then rolls a drop *count* from its weighted
  `dropCountProbability`, and finally picks that many items from the group's
  `weight`ed entries (gated on item min/max level + map ids; quest-constrained
  entries skipped). Item amounts roll between `minCount`..`maxCount`, rarity
  comes from the entry `grade`.
- **Individual boxes** (`individual_drop_box_ids`): per-player. Each entry
  group gates on **player level** (`minLevel`), rolls a drop *count* from
  weighted `dropCountProbability`, then picks items by `weight`, and rolls
  rarity from the item's weighted `gradeProbability` list.

Death flow: boss (`Friendly == 0 && Class >= 3`) → global drops unlocked (no
receiver) plus individual drops locked to *each* damage dealer; regular mob →
global + individual all locked to the tagged player. Drop positions scatter
within `drop_distance_random` around the corpse.

## Implemented flow

- `Context.Mobs`: global boxes gate on mob level, roll a weighted drop count,
  then pick weighted items (rarity + amount from the set entry); individual
  boxes gate on the player's level and do the same per dealer. Boss
  (`basic.class >= 3`) drops global loot unlocked plus per-dealer individual
  loot; regular mobs lock global + individual loot to the tagged player.
  `FieldNpc` tracks `damage_dealers` for per-dealer loot. The old hardcoded
  meso/meret/sp/stamina rolls and the on-hit sp orb were removed. Meso amounts
  come from the global boxes now (group 103 scales with NPC level).
- Hit drops: `drop_hit_rewards` rolls `global_hit_drop_box_ids` (unlocked) and
  `individual_hit_drop_box_ids` (locked to the hitter) on every hit while the
  mob is alive, including the killing blow (King Slime hit box 100000).
- Corpse drops: `drop_corpse_rewards` rolls the `dead_global_drop_box_ids`
  boxes and locks the loot to the player striking the body, on every corpse
  hit.
- Smart-drop: smart-gender groups filter by the player's gender; smart-drop-rate
  groups reweight by the player's job (`proper_job_weight`/`improper_job_weight`
  via `job_recommends`); all-zero-weight groups drop the single
  job-recommended item. `item:` docs carry `limit.gender`.
- Map gating: `map:<id>` docs carry `property.type`/`property.continent`;
  global drop groups gate on map-type/continent conditions while global and
  individual items gate on their `map_ids`. Unknown map metadata (stale cache)
  disables gating.
- Binding: `Context.Items.bind_if_needed` binds BindOnLoot items on pickup and
  BindOnLoot/BindOnEquip items on equip, marking `is_bound` (persisted boolean)
  and zeroing remaining trades. The bound owner is always the holding
  character, so the inventory packet derives the owner id/name from the
  character at serialize time when `is_bound` is set.
- Tradeability: fresh items get transfer flags + `remaining_trades` from
  metadata (`limit.transfer_type`, `limit.trade_max_rarity`,
  `property.tradable_count`). Contexts only deal with atoms; integer values are
  translated in the packets (`TransferFlags`) and at the DB boundary. Requires
  `item:` docs to carry the two projected fields and a fresh server cache.

## Ingest

`globalDropItemBox` + `globalDropItemSet` and `individualDropItem` are parsed
from `Server.m2d` (`ServerDropMapper`) and projected (`DropProjection`) into
the `table:` set as `table:globaldropitembox.xml` and
`table:individualdropitem.xml`. `NpcProjection` emits `drop_info` (box ids +
distance).