defmodule Ms2ex.UserMoveByPortalTest do
  use ExUnit.Case, async: true

  alias Ms2ex.Packets.UserMoveByPortal

  import Ms2ex.Packets.PacketReader

  test "drops the player 25 units above the anchor and carries the rotation" do
    character = %{object_id: 501}

    bytes =
      UserMoveByPortal.bytes(
        character,
        %{x: 0.0, y: 150.0, z: 1350.0},
        %{x: 0.0, y: 0.0, z: 270.0}
      )

    {opcode, packet} = get_short(bytes)
    {object_id, packet} = get_int(packet)
    {x, packet} = get_float(packet)
    {y, packet} = get_float(packet)
    {z, packet} = get_float(packet)
    {pitch, packet} = get_float(packet)
    {roll, packet} = get_float(packet)
    {yaw, packet} = get_float(packet)
    {is_portal, packet} = get_bool(packet)

    assert opcode == 0x60
    assert object_id == 501
    # the target anchor plus the 25-unit drop-in offset
    assert {x, y, z} == {0.0, 150.0, 1375.0}
    assert {pitch, roll, yaw} == {0.0, 0.0, 270.0}
    refute is_portal
    assert packet == <<>>
  end

  test "rotation defaults to zero when the anchor has none" do
    bytes = UserMoveByPortal.bytes(%{object_id: 1}, %{x: 1.0, y: 2.0, z: 3.0})

    {_opcode, packet} = get_short(bytes)
    {_object_id, packet} = get_int(packet)
    {_x, packet} = get_float(packet)
    {_y, packet} = get_float(packet)
    {_z, packet} = get_float(packet)
    {pitch, packet} = get_float(packet)
    {roll, packet} = get_float(packet)
    {yaw, packet} = get_float(packet)

    assert {pitch, roll, yaw} == {0.0, 0.0, 0.0}
  end
end
