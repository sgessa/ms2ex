defmodule Ms2ex.ItemUsePacketTest do
  use ExUnit.Case, async: true

  alias Ms2ex.Packets.ItemUse

  import Ms2ex.Packets.PacketReader

  test "encodes inventory expansion completion" do
    {opcode, packet} = ItemUse.expand_inventory() |> get_short()
    assert {opcode, packet} == {0xAD, <<0>>}
  end

  test "encodes quest scroll completion with the item id" do
    {opcode, packet} = ItemUse.quest_scroll(123_456) |> get_short()
    {command, packet} = get_byte(packet)
    {item_id, packet} = get_int(packet)

    assert {opcode, command, item_id, packet} == {0xAD, 4, 123_456, <<>>}
  end
end
