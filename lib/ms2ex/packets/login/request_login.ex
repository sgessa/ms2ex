defmodule Ms2ex.Packets.RequestLogin do
  import Ms2ex.Packets.PacketWriter

  def bytes(), do: build(__MODULE__)
end
