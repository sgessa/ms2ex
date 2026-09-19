defmodule Ms2ex.NavigationTest do
  use Ms2ex.DataCase, async: true

  alias Ms2ex.Navigation
  alias Ms2ex.Types.Coord

  @map_id 52_000_099

  # a single walkable triangle: navmesh-space verts (0,0,0), (1,0,0),
  # (0,0,1) — in map space a 100x100 floor patch at z=0 (navmesh y is up)
  @navmesh %{
    tiles: [
      %{
        verts:
          <<0.0::little-float-32, 0.0::little-float-32, 0.0::little-float-32,
            1.0::little-float-32, 0.0::little-float-32, 0.0::little-float-32,
            0.0::little-float-32, 0.0::little-float-32, 1.0::little-float-32>>,
        polys: [[0, 1, 2]]
      }
    ]
  }

  setup do
    stub_metadata(%{
      "map:#{@map_id}" => %{x_block: "nav_test"},
      "navmesh:nav_test" => @navmesh
    })

    :ok
  end

  test "snap_to_floor lifts a point that sits below the ground onto the surface" do
    # 5 units under the floor: the snap must land on z=0, keeping x/y
    snapped = Navigation.snap_to_floor(@map_id, %Coord{x: 25, y: -25, z: -5})

    assert %Coord{} = snapped
    assert snapped.x == 25.0
    assert snapped.y == -25.0
    assert snapped.z == 0.0
  end

  test "snap_to_floor lowers a point floating above the ground" do
    snapped = Navigation.snap_to_floor(@map_id, %Coord{x: 25, y: -25, z: 120})

    assert %Coord{} = snapped
    assert snapped.z == 0.0
  end

  test "snap_to_floor returns nil when nothing walkable is nearby" do
    # 500 units off the patch: beyond the lateral query box
    assert Navigation.snap_to_floor(@map_id, %Coord{x: 50_000, y: 50_000, z: 0}) == nil
  end

  test "snap_to_floor returns nil for maps without a navmesh" do
    assert Navigation.snap_to_floor(123_456, %Coord{x: 50, y: 50, z: -5}) == nil
  end
end
