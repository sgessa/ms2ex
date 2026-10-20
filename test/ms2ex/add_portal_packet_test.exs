defmodule Ms2ex.AddPortalPacketTest do
  use Ms2ex.DataCase, async: true

  alias Ms2ex.Packets
  alias Ms2ex.Types.Coord

  @portal %{
    id: 2,
    visible: false,
    enable: true,
    position: %Coord{x: 2175.0, y: 1350.0, z: 2400.0},
    rotation: %Coord{x: 0.0, y: 0.0, z: 0.0},
    dimension: %{x: 200.0, y: 200.0, z: 250.0},
    target_map_id: 52_000_105,
    object_id: 7,
    action_type: 1,
    minimap_visible: true,
    type: 6
  }

  test "add carries dimension, action_type and minimap_visible in the right field order" do
    decoded = Packets.Decoder.decode(:send, Packets.AddPortal.add(@portal))

    assert decoded.name == "ADD_PORTAL"
    assert decoded.command == :add

    assert decoded.fields == %{
             id: 2,
             visible: false,
             enable: true,
             position: @portal.position,
             rotation: @portal.rotation,
             dimension: %Coord{x: 200.0, y: 200.0, z: 250.0},
             target_map_id: 52_000_105,
             object_id: 7,
             action_type: 1,
             minimap_visible: true,
             type: 6
           }

    assert decoded.rest == <<>>
  end

  test "update and remove commands decode by their own layouts" do
    decoded = Packets.Decoder.decode(:send, Packets.AddPortal.update(@portal))

    assert decoded.command == :update
    assert decoded.fields == %{id: 2, visible: false, enable: true, minimap_visible: true}
    assert decoded.rest == <<>>

    decoded = Packets.Decoder.decode(:send, Packets.AddPortal.remove(9))

    assert decoded.command == :remove
    assert decoded.fields == %{id: 9}
    assert decoded.rest == <<>>
  end
end
