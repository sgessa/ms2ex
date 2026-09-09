defmodule Ms2ex.AddPortalPacketTest do
  use Ms2ex.DataCase, async: true

  alias Ms2ex.Packets
  alias Ms2ex.Types.Coord

  import Ms2ex.Packets.PacketReader

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
    bytes = Packets.AddPortal.bytes(@portal)

    {_opcode, packet} = get_short(bytes)
    {command, packet} = get_byte(packet)
    {id, packet} = get_int(packet)
    {visible, packet} = get_bool(packet)
    {enable, packet} = get_bool(packet)
    {_position, packet} = get_coord(packet)
    {_rotation, packet} = get_coord(packet)
    {dimension, packet} = get_coord(packet)
    {_model, packet} = get_ustring(packet)
    {target_map_id, packet} = get_int(packet)
    {object_id, packet} = get_int(packet)
    {action_type, packet} = get_int(packet)
    {minimap_visible, packet} = get_bool(packet)
    {_home_id, packet} = get_long(packet)
    {type, packet} = get_byte(packet)
    {_end_tick, packet} = get_int(packet)
    {_unknown, packet} = get_short(packet)
    {_start_tick, packet} = get_int(packet)
    {_has_password, packet} = get_bool(packet)
    {_owner_name, packet} = get_ustring(packet)
    {_empty1, packet} = get_ustring(packet)
    {_empty2, packet} = get_ustring(packet)

    assert command == 0x0
    assert id == 2
    assert {visible, enable} == {false, true}
    assert dimension == %Coord{x: 200.0, y: 200.0, z: 250.0}
    assert {target_map_id, object_id} == {52_000_105, 7}
    assert action_type == 1
    assert minimap_visible == true
    assert type == 6
    assert packet == <<>>
  end
end
