defmodule Ms2ex.Packets.CharacterCreate do
  import Ms2ex.Packets.PacketWriter

  @modes %{name_taken: 0xB}

  def name_taken() do
    __MODULE__
    |> build()
    |> put_byte(@modes.name_taken)
    |> put_short()
  end
end
