defmodule Ms2ex.Packets.FunctionCube do
  import Ms2ex.Packets.PacketWriter

  def load do
    build(__MODULE__)
    |> put_byte(0x2)
    |> put_int(0)
  end
end
