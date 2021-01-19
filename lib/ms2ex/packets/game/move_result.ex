defmodule Ms2ex.Packets.MoveResult do
  import Ms2ex.Packets.PacketWriter

  def bytes() do
    __MODULE__
    |> build()
    |> put_short()
  end
end
