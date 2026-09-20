# `Ms2ex.Navigation`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/navigation.ex#L1)

Navmesh queries for a map: position validity, floor snapping and
pathfinding. Navmesh coordinates are meters with Y up, so map positions
transform by a -90 degree rotation about X and a 1/100 scale.

The navmesh is cached as a graph: one node per convex polygon, with
adjacent polygons linked where they share an edge (polygon corners are
welded by position, which also connects polygons across tile borders).
Nearest-polygon queries run over a uniform grid index instead of scanning
every tile, and paths come from A* over the graph pulled tight with the
funnel algorithm.

# `point`

```elixir
@type point() :: {float(), float(), float()}
```

# `poly_key`

```elixir
@type poly_key() :: {non_neg_integer(), non_neg_integer()}
```

# `t`

```elixir
@type t() :: %Ms2ex.Navigation{by_key: term(), grid: term()}
```

# `__struct__`
*struct* 

Poly queries use these half extents (in navmesh meters): 2 across,
4 of height tolerance, 2 across.

# `find_path`

```elixir
@spec find_path(integer(), Ms2ex.Types.Coord.t(), Ms2ex.Types.Coord.t()) ::
  {:ok, [Ms2ex.Types.Coord.t()]} | :error
```

A corridor of walkable points from `from` to `to`, or `:error` when
either endpoint has no walkable ground or no connection exists between
them. The first and last points are the closest walkable points to the
requested positions; intermediate points are funnel-pulled corners of the
polygon corridor.

# `has_navmesh?`

Whether the map has walkable navmesh tiles.

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
