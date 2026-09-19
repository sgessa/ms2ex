defmodule Ms2ex.Navigation do
  @moduledoc """
  Navmesh queries for a map: position validity, floor snapping and
  pathfinding. Navmesh coordinates are meters with Y up, so map positions
  transform by a -90 degree rotation about X and a 1/100 scale.

  The navmesh is cached as a graph: one node per convex polygon, with
  adjacent polygons linked where they share an edge (polygon corners are
  welded by position, which also connects polygons across tile borders).
  Nearest-polygon queries run over a uniform grid index instead of scanning
  every tile, and paths come from A* over the graph pulled tight with the
  funnel algorithm.
  """

  alias Ms2ex.Storage
  alias Ms2ex.Types.Coord

  @doc """
  Poly queries use these half extents (in navmesh meters): 2 across,
  4 of height tolerance, 2 across.
  """
  @half_x 2.0
  @half_y 4.0
  @half_z 2.0

  # edge welding precision in navmesh meters (1mm): corners landing on the
  # same quantized point are one graph vertex, even across tile borders
  @weld 0.001

  # uniform grid cell size (navmesh meters) for nearest-poly lookups
  @cell 4.0

  defstruct [:by_key, :grid]

  @type t :: %__MODULE__{}
  @type poly_key :: {non_neg_integer(), non_neg_integer()}
  @type point :: {float(), float(), float()}

  @doc """
  A corridor of walkable points from `from` to `to`, or `:error` when
  either endpoint has no walkable ground or no connection exists between
  them. The first and last points are the closest walkable points to the
  requested positions; intermediate points are funnel-pulled corners of the
  polygon corridor.
  """
  @spec find_path(integer(), Coord.t(), Coord.t()) :: {:ok, [Coord.t()]} | :error
  def find_path(map_id, %Coord{} = from, %Coord{} = to) when is_integer(map_id) do
    with %__MODULE__{} = graph <- graph(map_id),
         false <- graph_empty?(graph),
         {start_key, start_pt} <- nearest_poly_entry(graph, to_nav(from)),
         {goal_key, goal_pt} <- nearest_poly_entry(graph, to_nav(to)),
         corridor when is_list(corridor) <- astar(graph, start_key, goal_key) do
      # the funnel returns the corner points ending at the goal
      path = [start_pt | funnel(graph, start_pt, goal_pt, corridor)]
      {:ok, Enum.map(path, &to_coord/1)}
    else
      _ -> :error
    end
  end

  def find_path(_, _, _), do: :error

  @doc """
  Whether a position stands on walkable ground. Maps without a navmesh
  accept every position.
  """
  def valid_position?(map_id, %Coord{} = position) when is_integer(map_id) do
    case graph(map_id) do
      nil -> true
      graph -> graph_empty?(graph) or nearest_poly_entry(graph, to_nav(position)) != nil
    end
  end

  def valid_position?(_, _), do: true

  @doc """
  The closest walkable point to a position, or nil when the map has no
  navmesh (or nothing walkable within the query box). Movement snaps npc
  positions to this point every step — pathed movement rides the ground
  surface instead of the straight line between waypoints, which cuts below
  it on slopes and stairs.
  """
  def snap_to_floor(map_id, %Coord{} = position) when is_integer(map_id) do
    with %__MODULE__{} = graph <- graph(map_id),
         false <- graph_empty?(graph),
         {_key, point} <- nearest_poly_entry(graph, to_nav(position)) do
      to_coord(point)
    else
      _ -> nil
    end
  end

  def snap_to_floor(_, _position), do: nil

  @doc "Whether the map has walkable navmesh tiles."
  def has_navmesh?(map_id) when is_integer(map_id) do
    case graph(map_id) do
      %__MODULE__{} = graph -> not graph_empty?(graph)
      _ -> false
    end
  end

  def has_navmesh?(_), do: false

  defp graph_empty?(%__MODULE__{by_key: by_key}), do: by_key == %{}

  # -- graph ------------------------------------------------------------------

  defmodule Poly do
    @moduledoc false
    # key: {tile_index, poly_index}
    # verts: polygon corners (fan order) in navmesh meters
    # center: average of the corners
    # edges: %{neighbor_key => {corner_a, corner_b}} shared edges
    defstruct [:key, :verts, :center, :edges]
    @type t :: %__MODULE__{}
  end

  defp graph(map_id) do
    case Storage.Maps.get_meta(map_id) do
      %{x_block: xblock} -> graph_for(xblock)
      _ -> nil
    end
  end

  defp graph_for(xblock) do
    case :persistent_term.get({:navgraph, xblock}, :missing) do
      :missing ->
        case Storage.get("navmesh", xblock) do
          nil -> nil
          doc -> parse_and_cache(xblock, doc)
        end

      cached ->
        cached
    end
  end

  defp parse_and_cache(xblock, doc) do
    polys =
      doc
      |> Map.get(:tiles, [])
      |> Enum.with_index()
      |> Enum.flat_map(fn {tile, tile_index} ->
        verts = Map.get(tile, :verts, <<>>)

        tile_polys =
          tile
          |> Map.get(:polys, [])
          |> Enum.with_index()
          |> Enum.map(fn {indices, poly_index} ->
            corners = Enum.map(indices, &tile_vertex(verts, &1))

            %Poly{
              key: {tile_index, poly_index},
              verts: corners,
              center: center(corners),
              edges: %{}
            }
          end)

        tile_polys
      end)

    polys = weld_edges(polys)
    by_key = Map.new(polys, &{&1.key, &1})
    graph = %__MODULE__{by_key: by_key, grid: build_grid(polys)}
    :persistent_term.put({:navgraph, xblock}, graph)
    graph
  end

  defp center(corners) do
    {sx, sy, sz} =
      Enum.reduce(corners, {0.0, 0.0, 0.0}, fn {x, y, z}, {ax, ay, az} ->
        {ax + x, ay + y, az + z}
      end)

    n = max(length(corners), 1)
    {sx / n, sy / n, sz / n}
  end

  # links polygons that share an edge: every fan-triangle edge is keyed by
  # its two quantized endpoints, and an edge keyed by exactly two polygons
  # (one on each side) becomes a neighbor link on both. Boundary edges
  # (single polygon) and geometry overlaps (3+) stay unlinked
  defp weld_edges(polys) do
    edge_map =
      polys
      |> Enum.flat_map(fn poly ->
        poly
        |> poly_edges()
        |> Enum.map(fn edge -> {edge_key(edge), {poly, edge}} end)
      end)
      |> Enum.reduce(%{}, fn {key, pair}, acc ->
        Map.update(acc, key, [pair], &[pair | &1])
      end)

    links =
      edge_map
      |> Enum.reduce(%{}, fn
        {_key, [{poly_a, edge}, {poly_b, _}]}, acc when poly_a.key != poly_b.key ->
          acc
          |> Map.update(poly_a.key, %{poly_b.key => edge}, &Map.put(&1, poly_b.key, edge))
          |> Map.update(poly_b.key, %{poly_a.key => edge}, &Map.put(&1, poly_a.key, edge))

        _edge, acc ->
          acc
      end)

    Enum.map(polys, &%{&1 | edges: Map.get(links, &1.key, %{})})
  end

  # fan-triangle edges of a convex polygon (corners in fan order)
  defp poly_edges(%Poly{verts: [v0 | rest]}) do
    rest
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.flat_map(fn
      [a, b] -> [{v0, a}, {a, b}, {b, v0}]
      _ -> []
    end)
    |> Enum.uniq()
  end

  defp poly_edges(%Poly{verts: []}), do: []

  defp edge_key({a, b}) do
    if a <= b, do: {quant(a), quant(b)}, else: {quant(b), quant(a)}
  end

  defp quant({x, y, z}) do
    {trunc(x / @weld), trunc(y / @weld), trunc(z / @weld)}
  end

  # -- grid index ---------------------------------------------------------------

  # maps grid cells (over the x/z plane) to the polygons whose bounding box
  # overlaps them, so nearest-poly queries only visit nearby polygons
  defp build_grid(polys) do
    Enum.reduce(polys, %{}, fn poly, grid ->
      {min_x, max_x, min_z, max_z} = bounds(poly.verts)

      cells =
        for cx <- cell_range(min_x, max_x), cz <- cell_range(min_z, max_z) do
          {cx, cz}
        end

      Enum.reduce(cells, grid, fn cell, grid ->
        Map.update(grid, cell, [poly.key], &[poly.key | &1])
      end)
    end)
  end

  defp bounds(verts) do
    Enum.reduce(verts, {nil, nil, nil, nil}, fn {x, _y, z}, {min_x, max_x, min_z, max_z} ->
      {
        if(is_nil(min_x) or x < min_x, do: x, else: min_x),
        if(is_nil(max_x) or x > max_x, do: x, else: max_x),
        if(is_nil(min_z) or z < min_z, do: z, else: min_z),
        if(is_nil(max_z) or z > max_z, do: z, else: max_z)
      }
    end)
  end

  defp cell_range(min, max) do
    first = floor(min / @cell)
    last = floor(max / @cell)
    first..last//1
  end

  # -- nearest polygon ----------------------------------------------------------

  # closest point on the nearest walkable polygon within the query box:
  # {poly_key, point} or nil. candidate polygons come from grid rings around
  # the query cell; the search stops once the best hit is closer than any
  # polygon a further ring could still hold
  @spec nearest_poly_entry(t(), point()) :: {poly_key(), point()} | nil
  defp nearest_poly_entry(%__MODULE__{} = graph, pos) do
    {qx, _qy, qz} = pos
    base = {floor(qx / @cell), floor(qz / @cell)}

    case do_nearest(graph, pos, base, 0, nil) do
      {key, _dist2, point} -> {key, point}
      nil -> nil
    end
  end

  @max_ring 256

  defp do_nearest(_graph, _pos, _base, ring, _best) when ring > @max_ring, do: nil

  defp do_nearest(graph, pos, base, ring, best) do
    best = search_rings(graph, pos, ring_cells(base, ring), best)

    # polygons in unsearched rings sit at least ring*@cell away horizontally,
    # so once the best hit is inside that radius nothing further can win
    if best != nil and elem(best, 1) <= :math.pow(ring * @cell, 2) do
      best
    else
      do_nearest(graph, pos, base, ring + 1, best)
    end
  end

  defp search_rings(_graph, _pos, [], best), do: best

  defp search_rings(graph, pos, [cell | rest], best) do
    best =
      graph.grid
      |> Map.get(cell, [])
      |> Enum.reduce(best, fn key, best ->
        poly = Map.fetch!(graph.by_key, key)
        best_poly_hit(pos, key, poly, best)
      end)

    search_rings(graph, pos, rest, best)
  end

  # keeps the closest point on `poly` when it lands inside the query box and
  # beats the current best
  defp best_poly_hit({qx, qy, qz}, key, poly, best) do
    poly.verts
    |> fan_triangles()
    |> Enum.map(fn {a, b, c} -> closest_on_triangle(qx, qy, qz, a, b, c) end)
    |> Enum.reduce(best, fn {dist2, cx, cy, cz}, best ->
      in_box? =
        abs(cx - qx) <= @half_x and abs(cz - qz) <= @half_z and abs(cy - qy) <= @half_y

      if in_box? and (best == nil or dist2 < elem(best, 1)) do
        {key, dist2, {cx, cy, cz}}
      else
        best
      end
    end)
  end

  defp ring_cells({bx, bz}, 0), do: [{bx, bz}]

  defp ring_cells({bx, bz}, ring) do
    for dx <- -ring..ring//1,
        dz <- -ring..ring//1,
        max(abs(dx), abs(dz)) == ring do
      {bx + dx, bz + dz}
    end
  end

  defp fan_triangles([v0 | rest]) do
    rest
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.flat_map(fn
      [a, b] -> [{v0, a, b}]
      _ -> []
    end)
  end

  defp fan_triangles([]), do: []

  # closest point on triangle — exact port of Ericson, Real-Time Collision
  # Detection 5.1.5; returns squared distance and the point. The three vertex
  # regions are checked first, then the three edge regions, then the face
  defp closest_on_triangle(px, py, pz, a, b, c) do
    terms = region_terms(px, py, pz, a, b, c)

    cond do
      terms.d1 <= 0 and terms.d2 <= 0 -> dist_point(px, py, pz, a)
      terms.d3 >= 0 and terms.d4 <= terms.d3 -> dist_point(px, py, pz, b)
      terms.d6 >= 0 and terms.d5 <= terms.d6 -> dist_point(px, py, pz, c)
      true -> closest_on_edge_or_face(px, py, pz, a, b, c, terms)
    end
  end

  defp region_terms(px, py, pz, a, b, c) do
    ab = sub(b, a)
    ac = sub(c, a)
    bc = sub(c, b)

    d1 = dot(ab, sub({px, py, pz}, a))
    d2 = dot(ac, sub({px, py, pz}, a))
    d3 = dot(ab, sub({px, py, pz}, b))
    d4 = dot(ac, sub({px, py, pz}, b))
    d5 = dot(ab, sub({px, py, pz}, c))
    d6 = dot(ac, sub({px, py, pz}, c))

    %{
      ab: ab,
      ac: ac,
      bc: bc,
      d1: d1,
      d2: d2,
      d3: d3,
      d4: d4,
      d5: d5,
      d6: d6,
      vc: d1 * d4 - d3 * d2,
      vb: d5 * d2 - d1 * d6,
      va: d3 * d6 - d5 * d4
    }
  end

  defp closest_on_edge_or_face(px, py, pz, a, b, _c, t) do
    cond do
      edge_ab?(t) ->
        dist_point(px, py, pz, add(a, scale(t.ab, t.d1 / (t.d1 - t.d3))))

      edge_ac?(t) ->
        dist_point(px, py, pz, add(a, scale(t.ac, t.d2 / (t.d2 - t.d6))))

      edge_bc?(t) ->
        dist_point(px, py, pz, add(b, scale(t.bc, (t.d4 - t.d3) / (t.d4 - t.d3 + (t.d5 - t.d6)))))

      true ->
        denom = t.va + t.vb + t.vc
        point = add(add(a, scale(t.ab, t.vb / denom)), scale(t.ac, t.vc / denom))
        dist_point(px, py, pz, point)
    end
  end

  defp edge_ab?(t), do: t.vc <= 0 and t.d1 >= 0 and t.d3 <= 0
  defp edge_ac?(t), do: t.vb <= 0 and t.d2 >= 0 and t.d6 <= 0
  defp edge_bc?(t), do: t.va <= 0 and t.d4 - t.d3 >= 0 and t.d5 - t.d6 >= 0

  defp sub({x1, y1, z1}, {x2, y2, z2}), do: {x1 - x2, y1 - y2, z1 - z2}
  defp add({x1, y1, z1}, {x2, y2, z2}), do: {x1 + x2, y1 + y2, z1 + z2}
  defp scale({x, y, z}, k), do: {x * k, y * k, z * k}
  defp dot({x1, y1, z1}, {x2, y2, z2}), do: x1 * x2 + y1 * y2 + z1 * z2

  defp dist_point(px, py, pz, {x, y, z}) do
    dx = x - px
    dy = y - py
    dz = z - pz
    d2 = dx * dx + dy * dy + dz * dz
    {d2, x, y, z}
  end

  # -- pathfinding ---------------------------------------------------------------

  # A* over polygon centers; returns the polygon corridor from start to goal.
  # the open set is a gb_sets keyed by {f, counter, key}: better entries sort
  # first, and the monotonic counter keeps re-inserted keys (improved paths)
  # as distinct elements instead of losing them to set dedup
  defp astar(graph, from_key, to_key) do
    goal_center = Map.fetch!(graph.by_key, to_key).center
    start = Map.fetch!(graph.by_key, from_key)
    f = dist(start.center, goal_center)
    open = :gb_sets.singleton({f, 0, from_key})
    astar_loop(graph, to_key, goal_center, open, %{from_key => 0.0}, %{}, 1)
  end

  defp astar_loop(graph, to_key, goal_center, open, g, parents, counter) do
    if :gb_sets.is_empty(open) do
      nil
    else
      {{_f, _counter, key}, open} = :gb_sets.take_smallest(open)
      settle(graph, to_key, goal_center, key, open, g, parents, counter)
    end
  end

  defp settle(_graph, to_key, _goal_center, key, _open, _g, parents, _counter) when key == to_key,
    do: walk_back(parents, to_key)

  defp settle(graph, to_key, goal_center, key, open, g, parents, counter) do
    poly = Map.fetch!(graph.by_key, key)
    g_key = Map.fetch!(g, key)

    {open, g, parents, counter} =
      relax_neighbors(graph, poly, g_key, to_key, open, g, parents, counter)

    astar_loop(graph, to_key, goal_center, open, g, parents, counter)
  end

  defp relax_neighbors(graph, poly, g_key, to_key, open, g, parents, counter) do
    poly.edges
    |> Map.keys()
    |> Enum.reduce({open, g, parents, counter}, fn neighbor, acc ->
      relax_edge(graph, poly, g_key, neighbor, to_key, acc)
    end)
  end

  defp relax_edge(graph, poly, g_key, neighbor, to_key, {open, g, parents, counter}) do
    neighbor_poly = Map.fetch!(graph.by_key, neighbor)
    tentative = g_key + dist(poly.center, neighbor_poly.center)

    if tentative < Map.get(g, neighbor, :infinity) do
      g = Map.put(g, neighbor, tentative)
      h = dist(neighbor_poly.center, Map.fetch!(graph.by_key, to_key).center)
      parents = Map.put(parents, neighbor, poly.key)
      open = :gb_sets.add_element({tentative + h, counter, neighbor}, open)
      {open, g, parents, counter + 1}
    else
      {open, g, parents, counter}
    end
  end

  defp walk_back(parents, key) do
    case Map.fetch(parents, key) do
      {:ok, prev} -> walk_back(parents, prev) ++ [key]
      :error -> [key]
    end
  end

  defp dist({ax, _ay, az}, {bx, _by, bz}) do
    dx = bx - ax
    dz = bz - az
    :math.sqrt(dx * dx + dz * dz)
  end

  # -- funnel (string pulling) ----------------------------------------------------

  # pulls the polygon corridor tight: walks the shared edges (portals) between
  # consecutive corridor polygons and keeps only the corner points the path
  # actually bends around. returns the full point list ending at the goal;
  # the caller prepends the start
  defp funnel(graph, start_pt, goal_pt, corridor) do
    portals = portal_edges(graph, corridor) |> List.to_tuple()
    # state: the apex (last emitted corner, the start at first) and the
    # current left/right boundary endpoints with the portal indices they
    # came from; both boundaries start uninitialized at the apex
    s = %{apex: start_pt, left: start_pt, right: start_pt, left_idx: 0, right_idx: 0}
    funnel_run(portals, 0, s, [], goal_pt)
  end

  # shared edges between consecutive corridor polygons, each oriented as
  # {left, right} relative to the walk direction through the corridor
  defp portal_edges(graph, [a_key, b_key | rest]) do
    a = Map.fetch!(graph.by_key, a_key)
    b = Map.fetch!(graph.by_key, b_key)
    {p1, p2} = Map.fetch!(a.edges, b_key)

    portal =
      if area2(a.center, b.center, p1) > 0 do
        {p1, p2}
      else
        {p2, p1}
      end

    [portal | portal_edges(graph, [b_key | rest])]
  end

  defp portal_edges(_graph, _corridor), do: []

  defp funnel_run(portals, i, _s, corners, goal) when i >= tuple_size(portals),
    do: Enum.reverse(corners) ++ [goal]

  defp funnel_run(portals, i, s, corners, goal) do
    {pl, pr} = elem(portals, i)

    case left_update(s, pl, i) do
      {:emit, s, restart_idx} ->
        funnel_run(portals, restart_idx, s, [s.apex | corners], goal)

      {:tighten, s} ->
        funnel_run(portals, i, s, corners, goal)

      :skip ->
        case right_update(s, pr, i) do
          {:emit, s, restart_idx} ->
            funnel_run(portals, restart_idx, s, [s.apex | corners], goal)

          {:tighten, s} ->
            funnel_run(portals, i + 1, s, corners, goal)

          :skip ->
            funnel_run(portals, i + 1, s, corners, goal)
        end
    end
  end

  # left boundary update: the candidate pulls inward when it moves the left
  # boundary toward the right side; a boundary still sitting on the apex
  # tightens to its first real candidate (a candidate equal to the boundary
  # is a no-op). a pulled candidate that crosses over the right boundary
  # emits the right endpoint as a corner
  defp left_update(s, pl, i) do
    pulls? = (s.apex == s.left and s.left != pl) or area2(s.apex, s.left, pl) < 0
    crosses? = s.apex != s.left and area2(s.apex, s.right, pl) > 0

    cond do
      pulls? and crosses? -> emit_corner(s, s.right, s.right_idx)
      pulls? -> {:tighten, %{s | left: pl, left_idx: i}}
      true -> :skip
    end
  end

  defp right_update(s, pr, i) do
    pulls? = (s.apex == s.right and s.right != pr) or area2(s.apex, s.right, pr) > 0
    crosses? = s.apex != s.right and area2(s.apex, s.left, pr) < 0

    cond do
      pulls? and crosses? -> emit_corner(s, s.left, s.left_idx)
      pulls? -> {:tighten, %{s | right: pr, right_idx: i}}
      true -> :skip
    end
  end

  defp emit_corner(_s, corner, corner_idx) do
    {:emit,
     %{apex: corner, left: corner, right: corner, left_idx: corner_idx, right_idx: corner_idx},
     corner_idx}
  end

  # twice the signed area of the triangle a-b-c in the x/z plane: positive
  # when c is left of the a→b direction
  defp area2({ax, _ay, az}, {bx, _by, bz}, {cx, _cy, cz}) do
    (bx - ax) * (cz - az) - (cx - ax) * (bz - az)
  end

  # -- coordinate conversion ---------------------------------------------------------

  # MS2 is Z-up; the navmesh is meters with Y up
  defp to_nav(%Coord{x: x, y: y, z: z}), do: {x / 100, z / 100, -y / 100}

  defp to_coord({cx, cy, cz}), do: %Coord{x: cx * 100, y: -cz * 100, z: cy * 100}

  defp tile_vertex(verts, index) do
    <<x::little-float-32, y::little-float-32, z::little-float-32>> =
      binary_part(verts, index * 12, 12)

    {x, y, z}
  end
end
