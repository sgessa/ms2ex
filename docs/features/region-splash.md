# Region & splash attacks

Status: partial. `ImmediateActive` / `Delay` are projected by the ingest,
but the server still uses a fixed radius instead of the exact skill geometry
and always lands the first hit immediately. Cube-magic-path placement also
has parity work left: rotated `fire_offset` is applied, but source-height
alignment and `ignore_adjust` snapping are not.

## Map-placed skill zones

Two flavors of map-placed zones are projected:

- **region skills** (`region_skills`): standalone zones with a fire
  interval (rest benches, hazard fields). Each zone gets a stable source
  id from the field's local counter, and entering players receive the
  zone frame (`RegionSkill.add_zone`) so the client renders it.
- **cube skills** (`cube_skills`): map cubes carrying a skill (the
  boost/slow lanes of Cave Depths, poison water, lava floors). The
  ingest keeps them even when the cube is also a fluid — the fluid case
  used to swallow the skill. Cube zones are not announced to clients;
  the field ticks them every second and applies the zone skill's attack
  to every player standing inside: the attack's damage rule first (a
  share of the target's max health for the falling rocks, broadcast as
  a tile damage record with the push direction), then the zone skill's
  effect as a buff (movement-speed lanes grant "Speed Up" +300% for 2s,
  refreshed while on the lane, mutually exclusive with the slow lane's
  debuff).

### Zone hit volume

Each zone's hit volume comes from the skill metadata (the level's first
attack `range`), resolved at zone load. The cube position is raised one
block (150) so the volume's base sits above the cell top:

- **box** (`type: 1`): rectangle **centered** on the cell position —
  x spans ±(width + range_add_x)/2, y spans ±(distance + range_add_y)/2
  — rising by height (+range_add_z). Cave Depths' lanes are 100×100
  centered squares on a 150 grid, so adjacent cells leave ~50-unit gaps;
  the short effect duration bridges them while running a lane.
- **cylinder** (`type: 2`): circle of radius = distance, rising by
  height. The falling-rock zones of the tutorial chase use this shape.

The player is tested as a body, not a point: a circle of radius 10 at
their position whose height spans feet to feet + 100. The zone hits
when that body overlaps the volume — so a player wading with their feet
below the band still connects (their body reaches into it), and the
small circle gives a 10-unit forgiveness at every horizontal edge.

## Player-cast region skills (Arcane Blast)

A cast whose skill carries a splash effect registers a region through
`Field.add_region_skill`: the client's @splash damage subcommand carries
the ground point, and the field broadcasts `RegionSkill.add` keyed on a
random source id, then fires the splash (`interval` between fires,
`fire_count` total, `remove_delay` the lifetime) applying the splash
skill's attack to hostile mobs in a fixed 800 radius (up to 8).

Each fire that lands hits broadcasts TWO records — the client's mob HP
update keys on the pair, and a plain damage record alone leaves the mob's
HP bar stale until the next unrelated hit:

- a **target record** (mode 0): the caster's object id, the splash skill,
the ground point, and one entry per mob with a uid chained from the
region's source id (`source_id << 32 | index`) and the mob's object id;
- a **region damage record** (mode 5): caster and owner both set to the
region's source id, one damage entry per mob (the mob's position, the
push direction away from the region center, the amount).
