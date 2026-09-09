defmodule Ms2ex.Packets.WorldMap do
  import Ms2ex.Packets.PacketWriter

  def open() do
    __MODULE__
    |> build()
    |> put_byte(0x0)
    |> put_bool(true)
    |> put_int(0)
    |> put_bool(false)
    |> put_byte(3)
    |> put_int(0)
  end
end
