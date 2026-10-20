defmodule Ms2ex.PacketLogTest do
  use ExUnit.Case, async: false

  alias Ms2ex.Enums
  alias Ms2ex.Net.Logger
  alias Ms2ex.Packets

  import Ms2ex.Packets.PacketWriter

  test "logs decoded fields when the packet has a spec" do
    path = Path.join(System.tmp_dir!(), "ms2ex_packet_log_test.log")
    Application.put_env(:ms2ex, :packet_log_file, path)

    opcode = Packets.name_to_opcode(:recv, "USER_CHAT")

    payload =
      ""
      |> put_int(Enums.ChatType.get_value(:all))
      |> put_ustring("hi")
      |> put_ustring("")
      |> put_long()

    try do
      assert :ok = Logger.log(:recv, opcode, payload)
    after
      Application.delete_env(:ms2ex, :packet_log_file)
    end

    line = File.read!(path)
    File.rm(path)

    assert line =~ "[RECV] USER_CHAT"
    assert line =~ "decoded: #{inspect(%{chat_type: :all, message: "hi", recipient: ""})}"
  end
end
