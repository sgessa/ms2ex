defmodule Ms2ex.Packets.DynamicChannel do
  import Ms2ex.Packets.PacketWriter

  def bytes() do
    __MODULE__
    |> build()
    |> put_byte(0x0)
    |> put_short(0xA)
    |> put_short(0x9)
    |> put_short(0x9)
    |> put_short(0x9)
    |> put_short(0x9)
    |> put_short(0xA)
    |> put_short(0xA)
    |> put_short(0xA)
  end
end
