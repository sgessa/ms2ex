defmodule Ms2ex.Packets.NpsInfo do
  import Ms2ex.Packets.PacketWriter

  def bytes() do
    __MODULE__
    |> build()
    |> put_long()
    |> put_ustring()
  end
end
