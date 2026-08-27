defmodule Ms2ex.Packets.CharacterCreate do
  import Ms2ex.Packets.PacketWriter

  @modes %{name_taken: 0xB}

  def name_taken() do
    create_error(@modes.name_taken)
  end

  defp create_error(mode, message \\ "") do
    __MODULE__
    |> build()
    |> put_byte(mode)
    |> put_ustring(message)
  end
end
