# Navmesh position validation

Status: the ingest builds a Recast/Detour navmesh per xblock from the
client's collision geometry (`--navmesh [xblocks]`; DotRecast pipeline using
doesMakeTOK entities, physics cubes and nif PhysX props) and stores a
tile/poly projection under the `navmesh` set. `Ms2ex.Navigation` answers
nearest-poly position queries, and the trigger runtime's move_user refuses
teleports to positions without walkable ground — scene-anchor portals off the
platform edge no longer drop players out of the world. `snap_to_floor/2`
returns the closest walkable surface point, and npc patrol movement snaps
every step onto it (mirroring how the reference walks npcs on the navmesh
surface rather than the straight line between waypoints) — models no longer
sink feet-deep into slopes and stairs while patrolling. There is no
straight-line fallback: like the reference, where every field requires its
navmesh file, patrols and scripted carries on maps without one refuse to
run (warning logged) and a step with no walkable surface holds position.

## Still missing

- auditing the generated meshes (nif assets whose llid lookup failed leave
  small gaps in walkable coverage). The ingest builds every map xblock by
  default now; per-map build failures are logged and retried on the next
  run. On maps without a navmesh, move_npc / move_user_path log a warning
  and do nothing — generate the navmesh to enable them
