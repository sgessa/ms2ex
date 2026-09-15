defmodule Ms2ex.InventoryPacketTest do
  use ExUnit.Case, async: true

  alias Ms2ex.Packets.InventoryItem

  import Ms2ex.Packets.PacketReader

  test "encodes the reference insufficient-merets inventory error" do
    {opcode, packet} = InventoryItem.error(:cannot_charge_meret) |> get_short()
    {command, packet} = get_byte(packet)
    {error, packet} = get_int(packet)

    assert {opcode, command, error, packet} == {0x21, 0xF, 34, <<>>}
  end
end
