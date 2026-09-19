# `Ms2ex.Navigation`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/navigation.ex#L1)

Point queries against a map's Recast navmesh: a position is valid when
the navmesh has walkable ground for it. Navmesh coordinates are meters
with Y up, so map positions transform by a -90 degree rotation about X
and a 1/100 scale.

# `has_navmesh?`

Whether the map has walkable navmesh tiles.

# `snap_to_floor`

The closest walkable point to a position, or nil when the map has no
navmesh (or nothing walkable within the query box). Movement snaps npc
positions to this point every step — pathed movement rides the ground
surface instead of the straight line between waypoints, which cuts below
it on slopes and stairs.

# `valid_position?`

Poly queries use these half extents (in navmesh meters): 2 across,
4 of height tolerance, 2 across.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
