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
sink feet-deep into slopes and stairs while patrolling, and spawn positions
are grounded the same way so npcs and mobs stand on the surface instead of
hovering at their authored height (plain-map and Coord spawn positions both
normalize through the snap; an authored position with no walkable surface
within tolerance is kept). There is no
straight-line fallback: like the reference, where every field requires its
navmesh file, patrols and scripted carries on maps without one refuse to
run (warning logged). Where the mesh exists, ground steps ride its surface
only while it agrees with the straight line between the authored waypoints
(within 15 units); where coverage is missing (unresolved nif props leave
small gaps) or the nearest layer deviates further, the step keeps the
authored line height — the waypoints are authored on the visual ground, so
the authored line is the truth and the mesh only corrects slopes and
stairs.

## Still missing

- auditing the generated meshes (nif assets whose llid lookup failed leave
  small gaps in walkable coverage). The ingest builds every map xblock by
  default now; per-map build failures are logged and retried on the next
  run. On maps without a navmesh, move_npc / move_user_path log a warning
  and do nothing — generate the navmesh to enable them
