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
random source id, then applies the splash skill's attack to hostile mobs
in a fixed 800 radius (up to 8).

The region's timeline must match the client's or hit visuals desync: the
add frame carries `next_tick` = now + interval (never 0 — a past tick
throws the client's zone timeline off), the first fire lands one
interval in (immediately for one-shots whose interval is 0, after the
splash `delay` when one is set), later fires each interval, and the zone
lives through its last fire plus `remove_delay` (minimum 100ms so the
client always sees the zone before the removal frame).

Each landed hit broadcasts the mob's health stat record (the client's
HP-bar update rides that — damage records only render numbers) plus one
**damage record** (mode 1) built from the splash cast — the same channel
normal skills use, which the client displays immediately. Target/region
record pairs (modes 0/5) keyed on the region's source id render on the
client's own zone timeline and lag seconds behind on this client build.
