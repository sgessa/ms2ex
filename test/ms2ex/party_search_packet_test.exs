defmodule Ms2ex.PartySearchPacketTest do
  use ExUnit.Case, async: true

  alias Ms2ex.Packets.PartySearch

  import Ms2ex.Packets.PacketReader

  test "encodes the error category as one byte" do
    {opcode, packet} = PartySearch.error(:max_member) |> get_short()
    {command, packet} = get_byte(packet)
    {category, packet} = get_byte(packet)
    {error, packet} = get_int(packet)

    assert {opcode, command, category, error, packet} == {0xBD, 0x4, 0, 110, <<>>}
  end
end
