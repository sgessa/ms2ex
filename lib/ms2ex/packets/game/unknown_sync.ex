defmodule Ms2ex.Packets.UnknownSync do
  import Ms2ex.Packets.PacketWriter

  def sync() do
    __MODULE__
    |> build()
    |> put_byte()
    |> put_int(Ms2ex.sync_ticks())
  end
end
