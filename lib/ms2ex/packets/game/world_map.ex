defmodule Ms2ex.Packets.WorldMap do
  import Ms2ex.Packets.PacketWriter

  def open() do
    __MODULE__
    |> build()
    |> put_byte(0x0)
    |> put_byte(0x0)
    |> put_byte(0x0)
    |> put_byte(0x0)
  end
end
