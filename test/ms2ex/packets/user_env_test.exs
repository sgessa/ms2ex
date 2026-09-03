defmodule Ms2ex.Packets.UserEnvTest do
  use ExUnit.Case, async: true

  alias Ms2ex.Packets.UserEnv

  import Ms2ex.Packets.PacketReader

  test "serializes an empty collected-item response" do
    {opcode, packet} = UserEnv.item_collects() |> get_short()
    {command, packet} = get_byte(packet)
    {count, packet} = get_int(packet)

    assert {opcode, command, count, packet} == {0xAA, 0x03, 0, <<>>}
  end
end
