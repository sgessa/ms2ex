defmodule Ms2ex.Packets.StatPoints do
  import Ms2ex.Packets.PacketWriter

  def bytes(_character) do
    __MODULE__
    |> build()
    |> put_byte(0x0)
    |> put_int(18)
  end
end
