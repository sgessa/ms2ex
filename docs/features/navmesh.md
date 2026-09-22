# Navmesh movement & routing

Status: navigation runs on the native Detour runtime. The ingest builds a
Recast/Detour navmesh per xblock from the client's collision geometry
(`--navmesh [xblocks]`; the DotRecast pipeline over doesMakeTOK entities,
physics cubes and nif PhysX props) and ships it twice: the full mesh-set
binary in Detour's own C-compatible format (the `navmesh_bin` set — magic
`MSET`, per-tile blobs the library consumes as-is) and a flat ETF
projection (the `navmesh` set — vertices and polygon loops, kept for
inspection tooling).

## Runtime

`Ms2ex.Navigation` is a thin façade over the Rust NIF (`native/navigation`,
built by `mix compile` via Rustler): coordinates convert between client
space (Z-up, centimeter-ish units) and navmesh space (Y up, meters) at the
boundary, and every query runs through the upstream C library — the same
lineage that builds the meshes.

- meshes load lazily once per map from the `navmesh_bin` set and are cached
  in `:persistent_term` keyed by xblock; missing meshes are negatively
  cached. Maps without a binary mesh have no walkable ground
  (`has_navmesh?/1` false, `find_path/3` `:error`, `snap_to_floor/2` nil,
  `valid_position?/2` accepts everything)
- `find_path/3` — nearest-poly lookup for both endpoints (half extents
  2 × 4 × 2 navmesh meters), the polygon corridor search, and the
  string-pulled straight path through it. A corridor that never reaches
  the goal poly (mesh gaps, stacked floors) is `:error`. Endpoints come
  back as authored when they sit inside their polygon; bends carry the
  mesh surface heights
- `snap_to_floor/2` — the closest walkable surface point with the height
  sampled from the containing detail triangle
- `valid_position?/2` — whether a position stands on walkable ground

Consumers: npc patrols route every authored waypoint over the mesh (legs
with no connected route leave the npc standing; air waypoints fly
straight; each route already ends exactly on the authored waypoint).
Waypoints carrying an arrive animation play it as an emote — the emote
machinery (`Types.FieldNpc.play_emote/4`) holds the next leg until its
beat, then the patrol departs. Mob movement rides the surface via per-step
snaps, radius-scattered spawns snap their scattered spot to the mesh
(falling back to the authored spawn), and the trigger runtime's move_user
refuses teleports to positions without walkable ground.

## Tests

The behavioral suite runs against synthetic mesh-set binaries
(`test/fixtures/navmesh/`, regenerable with the crate's `gen_fixtures`
binary — hand-authored tiles, nothing client-derived): the L-corridor
emits exactly its bend, stacked floors never connect, snaps pick the floor
the query is at, off-mesh goals error. Live verification against the game
client happens over a real ingest.

## Still missing

- mesh fragmentation on cube-built maps (150 components on 52000101) is
  ingest-side mesh quality — routes between disconnected patches fail even
  though both patches are walkable. Stale ETF mesh documents from earlier
  ingest generations (meshes whose map is no longer ingested) also linger
  in Redis; they are dead keys, never read
- a patrol leg whose route cannot resolve ends the whole patrol (the npc
  stands where it stopped); a more forgiving contract would skip the
  unreachable waypoint and keep the remaining legs — the reference does
  this. Same bucket: patrol population docs (script move_npc on a map
  whose first waypoint cannot path) refuse the patrol outright
- the crowd manager (agent steering for mobs) remains an option for later
