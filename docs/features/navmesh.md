# Navmesh position validation

Status: the ingest builds a Recast/Detour navmesh per xblock from the
client's collision geometry (`--navmesh [xblocks]`; DotRecast pipeline using
doesMakeTOK entities, physics cubes and nif PhysX props) and stores a
tile/poly projection under the `navmesh` set. `Ms2ex.Navigation` answers
nearest-poly position queries, and the trigger runtime's move_user refuses
teleports to positions without walkable ground — scene-anchor portals off the
platform edge no longer drop players out of the world.

## Still missing

- generating navmeshes for the remaining maps (the flag currently covers the
  verified tutorial xblocks)
- npc pathing queries over the stored tiles (prerequisite for mob AI)
- auditing the generated meshes (nif assets whose llid lookup failed leave
  small gaps in walkable coverage)
