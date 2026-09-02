defmodule Ms2ex.Packets.InGameRank do
  import Ms2ex.Packets.PacketWriter

  def load do
    __MODULE__
    |> build()
    |> put_byte(31)
    |> put_int(120)
    |> put_int(60)
  end
end
