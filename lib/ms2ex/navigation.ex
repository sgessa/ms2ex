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

  # spawn documents project positions as plain x/y/z maps
  def snap_to_floor(map_id, %{x: _, y: _, z: _} = position) when is_integer(map_id) do
    snap_to_floor(map_id, struct(Coord, Map.to_list(position)))
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
    # detail_tris: the tile's height patch resolved to 3D triangles — walk
    # heights inside the polygon come from these (the coarse polygon corners
    # are simplified and can sit well above the source collision)
    # raw_detail_tris: the poly's own packed tri bytes (edge boundary flags
    # and degenerate-edge checks)
    defstruct [:key, :verts, :center, :edges, detail_tris: [], raw_detail_tris: <<>>]
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

        detail_verts = Map.get(tile, :detail_verts, <<>>)
        detail_tris = Map.get(tile, :detail_tris, <<>>)
        patches = Map.get(tile, :detail_meshes, [])

        tile_polys =
          tile
          |> Map.get(:polys, [])
          |> Enum.with_index()
          |> Enum.map(fn {indices, poly_index} ->
            corners = Enum.map(indices, &tile_vertex(verts, &1))
            patch = Enum.at(patches, poly_index, %{})

            %Poly{
              key: {tile_index, poly_index},
              verts: corners,
              center: center(corners),
              edges: %{},
              detail_tris: poly_detail_tris(patch, detail_verts, detail_tris, verts, indices),
              raw_detail_tris:
                binary_part(
                  detail_tris,
                  Map.get(patch, :tri_base, 0) * 4,
                  Map.get(patch, :tri_count, 0) * 4
                )
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

    # recast poly meshes have T-junctions: one polygon's long boundary edge
    # can span several shorter edges of its neighbors, so exact endpoint
    # matches miss whole strips of floor. Boundary edges of different
    # polygons that overlap collinearly (within tolerance) are linked too —
    # the portal being the overlapping segment projected on the first edge
    boundary =
      edge_map
      |> Enum.filter(fn {_key, pairs} -> length(pairs) == 1 end)
      |> Enum.map(fn {_key, [{poly, edge}]} -> {poly.key, edge} end)

    tol = 0.15

    tolerant_links =
      for {{key_a, {a0, a1}}, ia} <- Enum.with_index(boundary),
          {key_b, {b0, b1}} <- Enum.drop(boundary, ia + 1),
          key_a != key_b,
          portal = collinear_overlap(a0, a1, {b0, b1}, tol),
          portal != nil,
          reduce: %{} do
        acc ->
          acc
          |> Map.update(key_a, %{key_b => portal}, &Map.put(&1, key_b, portal))
          |> Map.update(key_b, %{key_a => portal}, &Map.put(&1, key_a, portal))
      end

    Enum.map(polys, fn poly ->
      edges =
        Map.merge(Map.get(links, poly.key, %{}), Map.get(tolerant_links, poly.key, %{}), fn
          _k, exact, tolerant -> if map_size(exact) > 0, do: exact, else: tolerant
        end)

      %{poly | edges: edges}
    end)
  end

  # the overlapping sub-segment of two roughly collinear boundary edges, or
  # nil when they neither overlap along their axis nor lie within tolerance
  # of each other's line
  defp collinear_overlap({a0x, a0y, a0z}, {a1x, a1y, a1z}, {b0, b1}, tol) do
    dx = a1x - a0x
    dz = a1z - a0z
    len2 = dx * dx + dz * dz

    if len2 < 1.0e-9 do
      nil
    else
      tb0 = ((elem(b0, 0) - a0x) * dx + (elem(b0, 2) - a0z) * dz) / len2
      tb1 = ((elem(b1, 0) - a0x) * dx + (elem(b1, 2) - a0z) * dz) / len2
      lo = max(min(tb0, tb1), 0.0)
      hi = min(max(tb0, tb1), 1.0)

      collinear? =
        point_near_line?(elem(b0, 0), elem(b0, 2), a0x, a0z, dx, dz, tol) and
          point_near_line?(elem(b1, 0), elem(b1, 2), a0x, a0z, dx, dz, tol)

      if collinear? and hi - lo > 1.0e-6 do
        dy = a1y - a0y

        p0 = {a0x + lo * dx, a0y + lo * dy, a0z + lo * dz}
        p1 = {a0x + hi * dx, a0y + hi * dy, a0z + hi * dz}
        {p0, p1}
      end
    end
  end

  defp point_near_line?(px, pz, a0x, a0z, dx, dz, tol) do
    len = :math.sqrt(dx * dx + dz * dz)

    if len < 1.0e-9 do
      false
    else
      ex = px - a0x
      ez = pz - a0z
      abs(ex * dz - ez * dx) / len <= tol
    end
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
  # the reference's FindNearestPoly: every candidate polygon is evaluated
  # with ClosestPointOnPoly (interior points take their height from the
  # detail mesh; boundary points from the closest edge) and the winner is
  # the smallest distance, where the vertical delta of an over-poly point
  # only counts beyond the walkable climb allowance
  # Detour's PointInPolygon: ray-cast in the x/z plane over the poly corners
  defp point_in_poly?(x, z, verts) do
    inside =
      Enum.reduce(Enum.zip(verts, tl(verts ++ [hd(verts)])), false, fn {vi, vj}, c ->
        yi = elem(vi, 2)
        yj = elem(vj, 2)
        xi = elem(vi, 0)
        xj = elem(vj, 0)

        if yi > z != yj > z and
             x < (xj - xi) * (z - yi) / (yj - yi) + xi do
          not c
        else
          c
        end
      end)

    inside
  end

  defp nearest_poly_entry(%__MODULE__{} = graph, pos) do
    {qx, _qy, qz} = pos
    base = {floor(qx / @cell), floor(qz / @cell)}

    best =
      do_nearest_candidates(graph, base)
      |> Enum.map(fn poly -> poly_closest(poly, pos) end)
      |> Enum.min_by(fn {_poly, _closest, dist2} -> dist2 end, fn -> nil end)

    case best do
      nil -> nil
      {poly, closest, _dist2} -> {poly.key, closest}
    end
  end

  # candidate polys: every tile poly in the grid cells ringing the query
  # point (4m cells; one ring reaches well past the reference's 2m query
  # box, so coverage matches while the enumeration stays grid-driven)
  defp do_nearest_candidates(graph, {bx, bz}) do
    for dx <- -1..1//1,
        dz <- -1..1//1,
        key <- Map.get(graph.grid, {bx + dx, bz + dz}, []),
        poly = Map.fetch!(graph.by_key, key),
        into: %{} do
      {key, poly}
    end
    |> Map.values()
  end

  defp poly_closest(poly, pos) do
    {qx, qy, qz} = pos

    if point_in_poly?(qx, qz, poly.verts) do
      # over the polygon: the height comes from the detail patch (or the
      # poly's own fan when the tile carries no patch), and the vertical
      # delta only counts beyond the walkable climb allowance (0.7m)
      # poly_height over an in-poly point always yields a surface height
      {:ok, y} = poly_height(poly, pos)

      dy = abs(qy - y) - 70.0
      dist2 = if dy > 0, do: dy * dy, else: 0.0
      {poly, {qx, y, qz}, dist2}
    else
      boundary_result(poly, pos)
    end
  end

  defp boundary_result(poly, pos) do
    closest = poly_boundary_closest(poly, pos)
    dist2 = dist2_3d(pos, closest)
    {poly, closest, dist2}
  end

  defp dist2_3d({ax, ay, az}, {bx, by, bz}) do
    dx = ax - bx
    dy = ay - by
    dz = az - bz
    dx * dx + dy * dy + dz * dz
  end

  # GetPolyHeight: the point sits inside the polygon (2D) — its height comes
  # from the detail-mesh triangle containing it, else from the closest
  # detail edge of the patch
  defp poly_height(poly, pos) do
    case poly_detail_height(poly, elem(pos, 0), elem(pos, 2)) do
      {:ok, y} -> {:ok, y}
      :error -> poly_detail_edge_height(poly, pos)
    end
  end

  # ClosestHeightPointTriangle: barycentric containment in the x/z plane
  defp poly_detail_height(%Poly{detail_tris: []}, _x, _z), do: :error

  defp poly_detail_height(%Poly{detail_tris: tris}, x, z) do
    Enum.find_value(tris, :error, fn {a, b, c} ->
      closest_height_point_triangle(x, z, a, b, c)
    end)
  end

  # height from the closest detail edge of the patch
  defp poly_detail_edge_height(%Poly{detail_tris: []} = poly, pos) do
    poly_corner_edge_height(poly, pos)
  end

  defp poly_detail_edge_height(%Poly{detail_tris: tris}, pos) do
    {px, _py, pz} = pos

    tris
    |> Enum.flat_map(fn {a, b, c} -> [{a, b}, {b, c}, {c, a}] end)
    |> Enum.map(fn {va, vb} ->
      {d2, t} = distance_pt_seg_sqr_2d({px, pz}, va, vb)
      y = elem(va, 1) + (elem(vb, 1) - elem(va, 1)) * t
      {d2, y}
    end)
    |> Enum.min_by(fn {d2, _} -> d2 end)
    |> elem(1)
    |> then(fn y -> {:ok, y} end)
  end

  defp poly_corner_edge_height(%Poly{verts: corners}, pos) do
    {px, _py, pz} = pos

    corners
    |> Enum.zip(tl(corners ++ [hd(corners)]))
    |> Enum.map(fn {va, vb} ->
      {d2, t} = distance_pt_seg_sqr_2d({px, pz}, va, vb)
      y = elem(va, 1) + (elem(vb, 1) - elem(va, 1)) * t
      {d2, y}
    end)
    |> Enum.min_by(fn {d2, _} -> d2 end)
    |> elem(1)
    |> then(fn y -> {:ok, y} end)
  end

  # ClosestHeightPointTriangle: barycentric containment in the x/z plane;
  # interpolates the surface height when the point lies inside the triangle
  defp closest_height_point_triangle(px, pz, {ax, ay, az}, {bx, by, bz}, {cx, cy, cz}) do
    det = (bz - cz) * (ax - cx) + (cx - bx) * (az - cz)

    if abs(det) < 1.0e-9 do
      :error
    else
      l0 = ((bz - cz) * (px - cx) + (cx - bx) * (pz - cz)) / det
      l1 = ((cx - ax) * (px - cx) + (ax - cx) * (pz - cz)) / det
      l2 = 1 - l0 - l1

      if l0 >= -1.0e-6 and l1 >= -1.0e-6 and l2 >= -1.0e-6 do
        {:ok, l0 * ay + l1 * by + l2 * cy}
      else
        :error
      end
    end
  end

  # ClosestPointOnPolyBoundary: the closest point on the polygon's corner
  # edges (2D in the x/z plane, lerped back to 3D)
  defp poly_boundary_closest(%Poly{verts: corners}, pos) do
    {px, _py, pz} = pos

    corners
    |> Enum.zip(tl(corners ++ [hd(corners)]))
    |> Enum.map(fn {va, vb} ->
      {d2, t} = distance_pt_seg_sqr_2d({px, pz}, va, vb)
      closest = lerp_3d(va, vb, t)
      {d2, closest}
    end)
    |> Enum.min_by(fn {d2, _} -> d2 end)
    |> elem(1)
  end

  defp distance_pt_seg_sqr_2d({px, pz}, va, vb) do
    ax = elem(va, 0)
    az = elem(va, 2)
    bx = elem(vb, 0)
    bz = elem(vb, 2)
    dx = bx - ax
    dz = bz - az
    len2 = dx * dx + dz * dz

    t =
      if len2 > 0 do
        (((px - ax) * dx + (pz - az) * dz) / len2) |> min(1.0) |> max(0.0)
      else
        0.0
      end

    cx = ax + t * dx
    cz = az + t * dz
    ex = px - cx
    ez = pz - cz
    {ex * ex + ez * ez, t}
  end

  defp lerp_3d(a, b, t) do
    {
      elem(a, 0) + (elem(b, 0) - elem(a, 0)) * t,
      elem(a, 1) + (elem(b, 1) - elem(a, 1)) * t,
      elem(a, 2) + (elem(b, 2) - elem(a, 2)) * t
    }
  end

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

  defp settle(_graph, to_key, _goal_center, key, _open, _g, parents, _counter)
       when key == to_key do
    corridor = walk_back(parents, to_key)
    corridor
  end

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
  # string-pulled straight path through the corridor: the portals are the
  # corridor polygons' shared winding edges (left = verts[edge], right =
  # verts[edge + 1], exactly like GetPortalPoints), and the funnel is a
  # direct port of DotRecast's findStraightPath loop
  defp funnel(graph, start_pt, goal_pt, corridor) do
    portals =
      corridor
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.map(fn [a_key, b_key] -> portal_winding(graph, a_key, b_key) end)
      |> Enum.concat([{goal_pt, goal_pt}])
      |> List.to_tuple()

    s = %{apex: start_pt, left: start_pt, right: start_pt, apex_idx: 0, left_idx: 0, right_idx: 0}
    funnel_run(portals, 0, s, [corners: []], goal_pt)
  end

  # the winding edge of poly a shared with poly b: (left, right) = the
  # poly's winding edge vertices, matching GetPortalPoints
  defp portal_winding(graph, a_key, b_key) do
    a = Map.fetch!(graph.by_key, a_key)
    {c1, c2} = Map.fetch!(a.edges, b_key)
    n = length(a.verts)
    i1 = Enum.find_index(a.verts, fn v -> v == c1 end)
    i2 = Enum.find_index(a.verts, fn v -> v == c2 end)

    # the winding edge c1 → c2: left = verts[c1], right = verts[c2]. The
    # reversed order means the winding edge is c2 → c1. Tolerant portals
    # (interpolated corners) pass through as-is
    cond do
      i1 != nil and i2 != nil and rem(i1 + 1, n) == i2 ->
        {Enum.at(a.verts, i1), Enum.at(a.verts, i2)}

      i1 != nil and i2 != nil and rem(i2 + 1, n) == i1 ->
        {Enum.at(a.verts, i2), Enum.at(a.verts, i1)}

      true ->
        # the tolerant portal: the corners are already in nav space
        {c1, c2}
    end
  end

  defp funnel_run(portals, i, _s, opts, goal) when i >= tuple_size(portals),
    do: Enum.reverse(Keyword.get(opts, :corners, [])) ++ [goal]

  defp funnel_run(portals, i, s, opts, goal) do
    {new_left, new_right} = elem(portals, i)

    if area2(s.apex, s.right, new_right) >= 0 do
      cond do
        # the left boundary crossed past the new right: emit the left vertex
        s.left != s.apex and area2(s.apex, s.left, new_right) < 0 ->
          corners = [s.left | Keyword.get(opts, :corners, [])]

          s = %{
            s
            | apex: s.left,
              left: s.left,
              right: s.left,
              apex_idx: s.left_idx,
              left_idx: s.left_idx,
              right_idx: s.left_idx
          }

          funnel_run(portals, s.apex_idx + 1, s, [corners: corners], goal)

        true ->
          # tighten the right boundary
          s = %{s | right: new_right, right_idx: i}
          funnel_run(portals, i + 1, s, opts, goal)
      end
    else
      cond do
        # the left boundary doesn't tighten: skip this portal
        area2(s.apex, s.left, new_left) > 0 ->
          funnel_run(portals, i + 1, s, opts, goal)

        # the right boundary crossed past the new left: emit the right vertex
        s.right != s.apex and area2(s.apex, s.right, new_left) >= 0 ->
          corners = [s.right | Keyword.get(opts, :corners, [])]

          s = %{
            s
            | apex: s.right,
              left: s.right,
              right: s.right,
              apex_idx: s.right_idx,
              left_idx: s.right_idx,
              right_idx: s.right_idx
          }

          funnel_run(portals, s.apex_idx + 1, s, [corners: corners], goal)

        true ->
          # tighten the left boundary
          s = %{s | left: new_left, left_idx: i}
          funnel_run(portals, i + 1, s, opts, goal)
      end
    end
  end

  # DotRecast's TriArea2D
  # DotRecast's TriArea2D

  # twice the signed area of the triangle a-b-c in the x/z plane (the
  # negation of tri_area2)
  defp area2(a, b, c) do
    (elem(b, 0) - elem(a, 0)) * (elem(c, 2) - elem(a, 2)) -
      (elem(c, 0) - elem(a, 0)) * (elem(b, 2) - elem(a, 2))
  end

  # -- coordinate conversion  # -- coordinate conversion ---------------------------------------------------------

  # MS2 is Z-up; the navmesh is meters with Y up
  defp to_nav(%Coord{x: x, y: y, z: z}), do: {x / 100, z / 100, -y / 100}

  defp to_coord({cx, cy, cz}), do: %Coord{x: cx * 100, y: -cz * 100, z: cy * 100}

  # resolves a polygon's height-patch triangles to full 3D corners: the
  # detail tris are 4 bytes each (3 corner indices + a flag byte), and a
  # corner index below the poly's vert count references one of the poly's
  # own corners, otherwise a patch detail vertex
  defp poly_detail_tris(patch, detail_verts, detail_tris, tile_verts, poly_indices) do
    vert_base = Map.get(patch, :vert_base, 0)
    tri_base = Map.get(patch, :tri_base, 0)
    tri_count = Map.get(patch, :tri_count, 0)
    corner_count = length(poly_indices)

    detail_vertex = fn index ->
      <<x::little-float-32, y::little-float-32, z::little-float-32>> =
        binary_part(detail_verts, index * 12, 12)

      {x, y, z}
    end

    poly_corner = fn index ->
      tile_vertex(tile_verts, Enum.at(poly_indices, index))
    end

    for t <- 0..(tri_count - 1)//1 do
      <<b0, b1, b2, _flag>> = binary_part(detail_tris, (tri_base + t) * 4, 4)

      c0 =
        if b0 < corner_count,
          do: poly_corner.(b0),
          else: detail_vertex.(vert_base + b0 - corner_count)

      c1 =
        if b1 < corner_count,
          do: poly_corner.(b1),
          else: detail_vertex.(vert_base + b1 - corner_count)

      c2 =
        if b2 < corner_count,
          do: poly_corner.(b2),
          else: detail_vertex.(vert_base + b2 - corner_count)

      {c0, c1, c2}
    end
  end

  defp tile_vertex(verts, index) do
    <<x::little-float-32, y::little-float-32, z::little-float-32>> =
      binary_part(verts, index * 12, 12)

    {x, y, z}
  end
end
