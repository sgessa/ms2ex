# Mob spawn cycles

Status: working. Spawn points run tick-driven spawn cycles; the gaps are pets
and open-world spawn placement.

## How it works

- the initial population spawns on the first due cycle; mob deaths schedule
  the next cycle (full wipe → `regen_check_time` cooldown, partial kill → 2x
  cooldown while no cycle is pending); every due cycle refills to full
- zero-cooldown spawns never refill
- mob bodies stay for their `dead.time` window before removal
- event spawn points (`is_event: true`) are one-shot: script-summoned only
  (`spawn_monster`), never part of the regen machinery — and this holds
  whatever the map's script situation is; every other point loads per its
  `on_field_create` flag even when the map runs scripts (plain quest npcs on
  scripted maps must not vanish)
- each spawn point rolls from the pool the ingest projected for it: the
  mapspawntag rows name a difficulty band, and only mobs whose difficulty
  falls inside it join the pool — a map's mob list therefore matches what
  the client advertises for the map. Every pool member carries a spawn
  weight (tag breadth, rarity, low difficulty nudge it) and each spawned
  mob is a weighted roll over that pool
- mob gates are data-driven from the map's trigger script (`mob_gates`): when
  the last mob of a gated point dies, the blocking meshes drop (latched open
  across respawns, late joiners load them hidden) and the gate's guide event
  fires
- spawn points carry an explicit `spawn_radius`: 0 spawns exactly at the
  configured position, a positive radius scatters within that circle

## Still missing

- pet spawn rolls (`pet_population` / `pet_spawn_rate`) — not projected by
  the ingest yet
- navmesh-valid spawn picking for open-world population spawns (no radius
  metadata; they jitter ±250 around the point instead of snapping to spawn
  volumes)
