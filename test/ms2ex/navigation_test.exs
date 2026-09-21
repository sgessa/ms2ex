defmodule Ms2ex.NavigationTest do
  use Ms2ex.DataCase, async: true

  alias Ms2ex.Navigation
  alias Ms2ex.Types.Coord

  # a flat L-shaped navmesh (navmesh meters, Y up) of three convex quads:
  #
  #   z
  #   8 ┌─────┐
  #   4 │B│C│
  #   0 ─A─B──  x
  #     0 4 8
  #
  # A covers x 0..4 / z 0..4, B covers x 4..8 / z 0..4, C covers x 4..8 /
  # z 4..8. Tiles store float32 vertices and polys as vertex index loops,
  # wound clockwise seen from above (y up) like the ingested meshes — the
  # funnel's boundary signs depend on that winding
  setup do
    suffix = System.unique_integer([:positive])
    xblock = "test_nav_#{suffix}"
    map_id = 990_000_000 + suffix

    verts =
      [{0, 0, 0}, {4, 0, 0}, {4, 0, 4}, {0, 0, 4}, {8, 0, 0}, {8, 0, 4}, {4, 0, 8}, {8, 0, 8}]
      |> Enum.reduce(<<>>, fn {x, y, z}, acc ->
        acc <> <<x::little-float-32, y::little-float-32, z::little-float-32>>
      end)

    doc = %{tiles: [%{verts: verts, polys: [[0, 3, 2, 1], [1, 2, 5, 4], [2, 6, 7, 5]]}]}

    stub_metadata(%{
      "map:#{map_id}" => %{x_block: xblock},
      "navmesh:#{xblock}" => doc
    })

    on_exit(fn -> :persistent_term.erase({:navgraph, xblock}) end)

    %{map_id: map_id, xblock: xblock}
  end

  # navmesh meters -> client units (MS2 is Z-up, y = -nav z)
  defp coord(nx, nz, ny \\ 0.0), do: %Coord{x: nx * 100, y: -nz * 100, z: ny * 100}

  test "a straight walkable path has no intermediate corners", %{map_id: map_id} do
    assert {:ok, path} = Navigation.find_path(map_id, coord(1, 1), coord(3, 3))
    assert length(path) == 2
    [start, goal] = path
    assert %{x: 100.0, y: -100.0} = %{x: start.x, y: start.y}
    assert %{x: 300.0, y: -300.0} = %{x: goal.x, y: goal.y}
    assert_in_delta start.z, 0.0, 0.01
  end

  test "a path bending around the L walks the corridor corner", %{map_id: map_id} do
    assert {:ok, path} = Navigation.find_path(map_id, coord(1, 1), coord(5, 7))
    assert length(path) == 3
    [start, corner, goal] = path
    assert %{x: 100.0, y: -100.0} = %{x: start.x, y: start.y}
    # the corner is the shared portal endpoint (4, 4) in navmesh meters
    assert_in_delta corner.x, 400.0, 0.01
    assert_in_delta corner.y, -400.0, 0.01
    assert_in_delta goal.x, 500.0, 0.01
    assert_in_delta goal.y, -700.0, 0.01
  end

  test "endpoints snap to the closest walkable point", %{map_id: map_id} do
    assert {:ok, path} = Navigation.find_path(map_id, coord(0.5, 0.5), coord(7.5, 3.5))
    [start, goal] = path
    assert %Coord{x: 50.0, y: -50.0} = start
    assert %Coord{x: 750.0, y: -350.0} = goal
  end

  test "a goal off the mesh errors", %{map_id: map_id} do
    assert Navigation.find_path(map_id, coord(1, 1), coord(30, 30)) == :error
  end

  # two identical quads stacked 3m apart: their boundary edges are
  # horizontally collinear (a perfect T-junction overlap if height is
  # ignored), but they are separate floors and must never weld into one
  # graph — routes between them do not exist
  test "vertically stacked floors never connect", ctx do
    suffix = System.unique_integer([:positive])
    xblock = "test_stacked_#{suffix}"
    map_id = 991_000_000 + suffix

    verts =
      [{0, 0, 0}, {4, 0, 0}, {4, 0, 4}, {0, 0, 4}, {0, 3, 0}, {4, 3, 0}, {4, 3, 4}, {0, 3, 4}]
      |> Enum.reduce(<<>>, fn {x, y, z}, acc ->
        acc <> <<x::little-float-32, y::little-float-32, z::little-float-32>>
      end)

    stub_metadata(%{
      "map:#{map_id}" => %{x_block: xblock},
      "navmesh:#{xblock}" => %{tiles: [%{verts: verts, polys: [[0, 3, 2, 1], [4, 7, 6, 5]]}]}
    })

    on_exit(fn -> :persistent_term.erase({:navgraph, xblock}) end)

    # a route staying on one floor works
    assert {:ok, path} = Navigation.find_path(map_id, coord(1, 1), coord(3, 3))
    assert length(path) == 2
    # a route to the floor above has no connection
    above = %Coord{x: 300, y: -300, z: 300}
    assert Navigation.find_path(map_id, coord(1, 1), above) == :error
  end

  test "snap_to_floor returns the closest walkable surface point", %{map_id: map_id} do
    assert %Coord{} = snapped = Navigation.snap_to_floor(map_id, coord(2, 2))
    assert_in_delta snapped.x, 200.0, 0.01
    assert_in_delta snapped.y, -200.0, 0.01
    # floating above the mesh snaps down onto it (within the query box)
    assert %Coord{} = Navigation.snap_to_floor(map_id, coord(2, 2, 1.0))
    # sitting under the mesh lifts up onto the surface
    under = Navigation.snap_to_floor(map_id, %Coord{x: 200, y: -200, z: -100})
    assert %Coord{} = under
    assert_in_delta under.z, 0.0, 0.01
    assert Navigation.snap_to_floor(map_id, coord(30, 30)) == nil
  end

  test "snap_to_floor returns nil for maps without a navmesh" do
    assert Navigation.snap_to_floor(123_456, %Coord{x: 50, y: 50, z: -5}) == nil
  end

  test "valid_position? accepts on-mesh points and rejects far off-mesh ones", %{map_id: map_id} do
    assert Navigation.valid_position?(map_id, coord(2, 2))
    assert Navigation.valid_position?(map_id, coord(2, 2, 1.0))
    refute Navigation.valid_position?(map_id, coord(30, 30))
  end

  test "has_navmesh? reflects the mesh presence" do
    assert Navigation.has_navmesh?(-1) == false
  end
end
