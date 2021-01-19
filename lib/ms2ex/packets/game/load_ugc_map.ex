defmodule Ms2ex.Packets.LoadUgcMap do
  import Ms2ex.Packets.PacketWriter

  def bytes() do
    __MODULE__
    |> build()
    |> put_bytes(String.duplicate(<<0x0>>, 9))
  end
end
