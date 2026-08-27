defmodule Ms2ex.Packets.RevivalCount do
  import Ms2ex.Packets.PacketWriter

  def bytes(count \\ 0) do
    __MODULE__
    |> build()
    |> put_int(count)
  end
end
