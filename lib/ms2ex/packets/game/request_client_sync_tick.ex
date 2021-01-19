defmodule Ms2ex.Packets.RequestClientSyncTick do
  import Ms2ex.Packets.PacketWriter

  def bytes(tick) do
    __MODULE__
    |> build()
    |> put_int(tick)
  end
end
