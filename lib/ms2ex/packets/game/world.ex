defmodule Ms2ex.Packets.World do
  import Ms2ex.Packets.PacketWriter

  def bytes do
    build(__MODULE__)
  end
end
