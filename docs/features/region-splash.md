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

Cells sit on a 150 grid and positions are exact multiples, so the z band
hits a standing player's body for both cube-position conventions.
