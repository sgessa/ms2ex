defmodule Ms2ex.Storage.MapsPortalsTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Ms2ex.Storage.Maps

  import Ms2ex.TestHelpers

  setup do
    stub_metadata(%{
      "map:52000104" => %{
        portals: [
          %{
            id: 1,
            enable: false,
            visible: false,
            minimap_visible: true,
            position: %{x: 1, y: 2, z: 3},
            rotation: %{x: 0, y: 0, z: 0},
            target_map_id: 0,
            target_portal_id: 0
          },
          %{
            id: 2,
            enable: true,
            visible: false,
            minimap_visible: true,
            position: %{x: 4, y: 5, z: 6},
            rotation: %{x: 0, y: 0, z: 0},
            target_map_id: 52_000_105,
            target_portal_id: 1
          }
        ]
      }
    })

    :ok
  end

  test "disabled portals still load so scripts can enable them later" do
    portals = Maps.get_portals(52_000_104)

    assert Enum.map(portals, & &1.id) == [1, 2]
    assert Enum.find(portals, &(&1.id == 1)).enable == false
  end
end
