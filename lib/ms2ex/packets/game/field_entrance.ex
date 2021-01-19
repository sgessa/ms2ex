defmodule Ms2ex.Packets.FieldEntrance do
  import Ms2ex.Packets.PacketWriter


  def bytes() do
    __MODULE__
    |> build()
    |> put_byte(0x0)
    |> put_int(0)
  end
end
