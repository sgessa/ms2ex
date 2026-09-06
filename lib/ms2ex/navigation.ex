defmodule Ms2ex.Navigation do
  @moduledoc """
  Point queries against a map's Recast navmesh, mirroring the reference
  field's ValidPosition: a position is valid when the navmesh has walkable
  ground for it. Navmesh coordinates are meters with Y up, so map positions
  transform by a -90 degree rotation about X and a 1/100 scale.
  """

  alias Ms2ex.Storage
  alias Ms2ex.Types.Coord

  @doc """
  The reference queries Detour's FindNearestPoly with these half extents
  (in navmesh meters): 2 across, 4 of height tolerance, 2 across.
  """
  @half_x 2.0
  @half_y 4.0
  @half_z 2.0

  def valid_position?(map_id, %Coord{} = position) when is_integer(map_id) do
    case tiles(map_id) do
      nil -> true
      [] -> true
      tiles -> nearest_poly(tiles, position) != nil
    end
  end

  def valid_position?(_, _), do: true

  # returns the closest point on the nearest walkable poly, or nil.
  # mirrors Detour's FindNearestPoly: candidate polys are those whose
  # closest point falls within the query box around the position
  defp nearest_poly(tiles, %Coord{x: x, y: y, z: z}) do
    # MS2 is Z-up; the navmesh is meters with Y up
    nx = x / 100
    ny = z / 100
    nz = -y / 100

    candidates =
      Enum.flat_map(tiles, fn tile ->
        tile.polys
        |> Enum.map(&poly_closest(tile, &1, nx, ny, nz))
        |> Enum.reject(&is_nil/1)
      end)

    candidates
    |> Enum.filter(fn {_dist, cx, cy, cz} ->
      abs(cx - nx) <= @half_x and abs(cy - ny) <= @half_y and abs(cz - nz) <= @half_z
    end)
    |> Enum.min_by(&elem(&1, 0), fn -> nil end)
    |> case do
      nil -> nil
      {_dist, cx, cy, cz} -> {cx, cy, cz}
    end
  end

  # Detour polygons are convex fans: triangles (v0, vi, vi+1)
  defp poly_closest(tile, poly, nx, ny, nz) do
    verts = Enum.map(poly, &tile_vertex(tile, &1))

    case verts do
      [v0 | rest] when length(rest) >= 2 ->
        rest
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.flat_map(fn
          [a, b] -> [{v0, a, b}]
          _ -> []
        end)
        |> Enum.map(fn {a, b, c} -> closest_on_triangle(nx, ny, nz, a, b, c) end)
        |> Enum.min_by(&elem(&1, 0))

      _ ->
        nil
    end
  end

  defp tile_vertex(tile, index) do
    <<x::little-float-32, y::little-float-32, z::little-float-32>> =
      binary_part(tile.verts, index * 12, 12)

    {x, y, z}
  end

  # closest point on triangle — exact port of Ericson, Real-Time Collision
  # Detection 5.1.5; returns squared distance and the point. The three vertex
  # regions are checked first, then the three edge regions, then the face
  defp closest_on_triangle(px, py, pz, a, b, c) do
    terms = region_terms(px, py, pz, a, b, c)

    cond do
      terms.d1 <= 0 and terms.d2 <= 0 -> dist_point(px, py, pz, a)
      terms.d3 >= 0 and terms.d4 <= terms.d3 -> dist_point(px, py, pz, b)
      terms.d5 >= 0 and terms.d6 <= terms.d5 -> dist_point(px, py, pz, c)
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
    d5 = dot(ac, sub({px, py, pz}, c))
    d6 = dot(bc, sub({px, py, pz}, c))

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

  # -- cached parsed tiles ---------------------------------------------------

  defp tiles(map_id) do
    xblock = map_id |> Storage.Maps.get_meta() |> Map.get(:x_block)

    case :persistent_term.get({:navmesh, xblock}, :missing) do
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
    tiles =
      doc
      |> Map.get(:tiles, [])
      |> Enum.map(fn tile ->
        verts = Map.get(tile, :verts, <<>>)
        polys = Map.get(tile, :polys, [])
        %{verts: verts, polys: polys}
      end)

    :persistent_term.put({:navmesh, xblock}, tiles)
    tiles
  end
end
