defmodule Ms2ex.Packets.SyncNumber do
  import Ms2ex.Packets.PacketWriter

  def bytes() do
    __MODULE__
    |> build()
    |> put_byte(0x0)
  end
end
