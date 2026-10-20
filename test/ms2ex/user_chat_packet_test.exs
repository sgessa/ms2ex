defmodule Ms2ex.UserChatPacketTest do
  use Ms2ex.DataCase, async: true

  alias Ms2ex.Enums
  alias Ms2ex.Packets

  import Ms2ex.Packets.PacketWriter

  test "decodes a client chat message through the handler spec" do
    opcode = Packets.name_to_opcode(:recv, "USER_CHAT")

    payload =
      ""
      |> put_int(Enums.ChatType.get_value(:all))
      |> put_ustring("hello world")
      |> put_ustring("")
      |> put_long()

    decoded = <<opcode::little-16, payload::binary>> |> Packets.Decoder.decode()

    assert decoded.name == "USER_CHAT"
    assert decoded.command == nil

    assert decoded.fields == %{
             chat_type: :all,
             message: "hello world",
             recipient: ""
           }

    assert decoded.rest == <<>>
  end

  test "decode_hex accepts a logged hex string with separators" do
    bytes = "" |> put_short(0x1234) |> put_int(7)

    spaced_hex =
      bytes
      |> Base.encode16(case: :lower)
      |> String.graphemes()
      |> Enum.chunk_every(2)
      |> Enum.map_join(" ", &List.to_string/1)

    decoded = Packets.Decoder.decode_hex(spaced_hex)
    assert decoded.opcode == 0x1234
  end
end
