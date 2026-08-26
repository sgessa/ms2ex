defmodule Ms2ex.Packets.UserState do
  import Ms2ex.Packets.PacketWriter

  def bytes(character) do
    __MODULE__
    |> build()
    |> put_int(character.object_id)
    |> put_byte(0x05)
  end
end
