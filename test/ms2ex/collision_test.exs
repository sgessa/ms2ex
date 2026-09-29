defmodule Ms2ex.CollisionTest do
  use ExUnit.Case, async: true

  alias Ms2ex.Collision
  alias Ms2ex.Types.Coord

  # yaw 0 faces -y; a facing of 90 faces +x. build_prism projects the
  # footprint forward along the facing
  @anchor %Coord{x: 0.0, y: 0.0, z: 100.0}

  defp prism(range, angle \\ 0.0), do: Collision.build_prism(range, @anchor, angle)

  defp inside?(prism, x, y, z \\ 100.0) do
    Collision.contains?(prism, %{x: x, y: y, z: z})
  end

  describe "box ranges" do
    test "a box of width 100 and distance 250 covers ahead, not behind or beside" do
      prism = prism(%{type: 1, width: 100.0, distance: 250.0})

      assert inside?(prism, 0.0, -100.0)
      assert inside?(prism, 40.0, -240.0)
      refute inside?(prism, 0.0, 100.0)
      refute inside?(prism, 200.0, -100.0)
    end

    test "range_add widens and lengthens the box" do
      prism =
        prism(%{type: 1, width: 100.0, distance: 250.0, range_add_x: 100.0, range_add_y: 50.0})

      assert inside?(prism, 0.0, -90.0, 100.0) and inside?(prism, 90.0, -90.0)
      assert inside?(prism, 0.0, -295.0)
    end

    test "the facing rotates the footprint" do
      # facing +x: the volume extends along +x
      prism = prism(%{type: 1, width: 100.0, distance: 250.0}, 90.0)

      assert inside?(prism, 100.0, 0.0)
      refute inside?(prism, 0.0, -100.0)
    end

    test "the height band bounds the z axis" do
      prism = prism(%{type: 1, width: 100.0, distance: 250.0, height: 200.0})

      assert inside?(prism, 0.0, -100.0, 250.0)
      refute inside?(prism, 0.0, -100.0, 350.0)
      refute inside?(prism, 0.0, -100.0, 50.0)
    end
  end

  test "a cylinder covers a circle of the range distance" do
    prism = prism(%{type: 2, distance: 300.0})

    assert inside?(prism, 0.0, -250.0)
    assert inside?(prism, 200.0, -200.0)
    refute inside?(prism, 0.0, 400.0)
  end

  test "a frustum narrows from width to end width" do
    prism = prism(%{type: 3, width: 200.0, end_width: 50.0, distance: 300.0})

    # near edge is wide, far edge is narrow
    assert inside?(prism, 80.0, -80.0)
    refute inside?(prism, 40.0, -280.0)
    assert inside?(prism, 10.0, -280.0)
  end

  test "a hole cylinder excludes its inner circle" do
    prism = prism(%{type: 4, width: 100.0, end_width: 300.0})

    assert inside?(prism, 0.0, -250.0)
    refute inside?(prism, 0.0, -50.0)
  end

  test "a range with no volume is never inside" do
    prism = prism(%{type: 0, width: 100.0, distance: 250.0})

    refute inside?(prism, 0.0, -100.0)
  end

  test "the rotate offset rides on the facing" do
    # rotate_z_degree 90 with facing 0 behaves like facing 90
    prism = prism(%{type: 1, width: 100.0, distance: 250.0, rotate_z_degree: 90.0})

    assert inside?(prism, 100.0, 0.0)
    refute inside?(prism, 0.0, -100.0)
  end
end
