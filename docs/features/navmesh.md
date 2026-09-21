# Navmesh movement & routing

Status: the ingest builds a Recast/Detour navmesh per xblock from the
client's collision geometry (`--navmesh [xblocks]`; DotRecast pipeline using
doesMakeTOK entities, physics cubes and nif PhysX props) and stores a
tile/poly projection under the `navmesh` set: float32 vertices, polygon
vertex index loops wound clockwise seen from above (y up — the funnel's
boundary-sign conventions depend on this winding), and the detail height
patch per polygon. `Ms2ex.Navigation` serves three groups of queries on it.

## Graph

Tiles load lazily into a cached graph (one node per convex polygon, keyed by
tile/poly index). Polygons link where they share an edge: exact edge matches
(corners welded by position at 1mm, which also joins polys across tile
borders) plus tolerant overlaps for recast's T-junctions — one polygon's long
boundary edge spanning several shorter edges of its neighbors. The tolerant
overlap requires the two edges to ride the same height along the shared
horizontal span: T-junction edges lie on one surface, while vertically
stacked floors also have horizontally collinear boundary edges and must
never weld into one graph (crossing them teleports the route between
levels). Exact edge matches win over tolerant overlaps on the same
neighbor. A uniform grid index over the x/z plane backs nearest-poly
queries.

## Position queries

- `valid_position?/2` — whether a position stands on walkable ground; maps
  without a navmesh accept every position.
- `snap_to_floor/2` — the closest walkable surface point (or nil), with the
  height sampled from the containing detail triangle: the simplified
  polygon corners deviate from the source collision by up to recast's
  edge-max-error (1.3m), so heights interpolate the detail patch instead.
  Mob movement snaps every step onto it, and spawn positions ground
  the same way — a mesh-era workaround pending removal (see the
  migration plan): the meshes already match the authored ground, so
  spawns should keep their authored positions.

## Routing

`find_path/3` returns a corridor of walkable points between two positions
(endpoints snap to the closest walkable point; no connection is `:error`).
The corridor comes from A* over the graph, then a funnel (string-pulling)
collapses it to the minimal corner set: consecutive corridor polygons
contribute a portal — the shared edge ordered along the first polygon's
winding — and the walk keeps the tightest wedge (apex plus left/right
boundary rays) the portals allow. A portal vertex swinging past the
opposite boundary pinches the wedge at that boundary's vertex, which
becomes a path corner; the apex moves onto it and the walk restarts from
behind it. A start standing on the first portal (within a millimeter)
skips it, and consecutive equal points collapse — the goal portal
legitimately pinches at the goal itself, which dedupes against the goal
append.

Consumers: npc patrols route every authored waypoint over the mesh (see
`field-manager.md`'s patrol section — legs with no connected route leave
the npc standing instead of walking a straight line that can leave the
ground; air waypoints fly straight; the final segment of every leg lands on
the authored waypoint exactly), the trigger runtime's move_user refuses
teleports to positions without walkable ground — scene-anchor portals off
the platform edge no longer drop players out of the world — and mob
movement rides the surface via per-step snaps. Patrol legs walk the routed
path's corner heights directly — the coarse polygon corners lie on the
source surface, but mid-segment height re-sampling on stair polys (the
smooth-path re-sample) arrives with the Detour migration.

## Still missing

- **migrating the runtime onto the native Detour library** — see
  [plans/detour-migration.md](../plans/detour-migration.md): the ingest
  already serializes the full mesh-set binary; the plan replaces this
  hand-ported geometry core with the upstream library behind a small NIF

- auditing the generated meshes: nif assets whose llid lookup failed leave
  small gaps in walkable coverage, and cube-built floors fragment into
  many disconnected components on some maps (route endpoints may be
  walkable yet unconnected). The ingest builds every map xblock by
  default now; per-map build failures are logged and retried on the next
  run. On maps without a navmesh, move_npc / move_user_path log a warning
  and do nothing — generate the navmesh to enable them
- only a few xblocks were rebuilt after the ingest's cube index-buffer
  fix; the rest still carry meshes built with the broken index and need a
  full `--navmesh` re-run
