# Housing & UGC cube system

Status: open. The cube packet surface is mostly unimplemented:
`RequestCube` handles `place_cube` (quest liftable placement), `remove_cube`,
and the liftup object pair; every other mode falls into the unhandled-mode
warning.

## Liftable object weapons (implemented)

Maps project `object_weapons` (throwable barrels, crates, pots) from their
block data, keyed by block tile. The client requests a lift with
`RequestCube` 0x11 carrying the tile coordinate; the field manager rolls
one of the weapon's item ids (rotating with the shared tick), reads the
throw skill + level from the item metadata (`skill_weapon_id` /
`skill_weapon_level`), tracks the hold per character, and broadcasts the
pickup with the respawn deadline (shared tick + respawn delay) so clients
return the container visual on time. Lifting enters the battle stance, and
a spawn-npc roll may release a hidden occupant from the container.

While a hold is out, the skill-use gate refuses every cast except the held
object's throw skill; casting it consumes the hold. The throw's impact is
client-resolved: the attack's reported hit chain is relayed to everyone
else as the target-mode skill-damage record. `RequestCube` 0x12 drops the
held object without throwing it (broadcast + clear). Leaving the field
releases the hold silently.

Failure replies ride the response-cube error command (0x02) with the
ugc-map error code: no weapon at the tile (or unthrowable item) → 37
(`no_cube_to_lift`), lifting while already holding → 95
(`not_allowed_item`).

## Still missing

- hold cube; buy/forfeit/extend plot; place/rotate/replace cube; home
  name / passcode / vote / message; clear cubes; plot area and height
  changes; design rank rewards; permissions; save/load home; blueprints;
  kick out; background / lighting / camera
- plots, furnishings and home ownership have no server model yet
- field-load cube packets send empty data
- layout blueprints depend on this system (the blueprint block written next
  to the UGC descriptor is currently all zeroes — see ugc.md)
- the guild house map's interior content depends on this too (see
  guild-system.md)
