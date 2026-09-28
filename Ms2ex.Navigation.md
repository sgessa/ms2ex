# `Ms2ex.Navigation`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/navigation.ex#L1)

Navmesh queries for a map: position validity, floor snapping and
pathfinding. Navmesh coordinates are meters with Y up, so map positions
transform by a -90 degree rotation about X and a 1/100 scale.

Queries run on the native Detour runtime over the full mesh binary the
ingest ships (the `navmesh_bin` set) — the same library lineage the
meshes are built with. Meshes load lazily once per map and are cached
for the node's lifetime; maps without a binary mesh have no walkable
ground.

# `find_path`

```elixir
@spec find_path(integer(), Ms2ex.Types.Coord.t(), Ms2ex.Types.Coord.t()) ::
  {:ok, [Ms2ex.Types.Coord.t()]} | {:partial, [Ms2ex.Types.Coord.t()]} | :error
```

Returns the string-pulled route between two points.

`{:ok, path}` - a full route reaches the goal. `{:partial, path}` -
the goal sits on another mesh island (stacked floors, gaps): the route
ends at the closest reachable point, so a follower will never close
the remaining distance. `:error` - no walkable ground under an
endpoint.

# `has_navmesh?`

Whether the map has walkable navmesh tiles.

# `random_point_around`

```elixir
@spec random_point_around(integer(), Ms2ex.Types.Coord.t(), number()) ::
  Ms2ex.Types.Coord.t() | nil
```

A random walkable point within `radius` of `center`, or nil when the map
has no navmesh or nothing walkable sits inside the circle. This is how
idle mobs pick their wander destinations around the spawn point.

# `snap_to_floor`

The closest walkable point to a position, or nil when the map has no
navmesh (or nothing walkable within the query box). Movement snaps npc
positions to this point every step — pathed movement rides the ground
surface instead of the straight line between waypoints, which cuts below
it on slopes and stairs.

# `valid_position?`

Whether a position stands on walkable ground. Maps without a navmesh
accept every position.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
