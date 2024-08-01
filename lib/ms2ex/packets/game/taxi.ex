defmodule Ms2ex.Packets.Taxi do
  import Ms2ex.Packets.PacketWriter

  def discover(map_id) do
    __MODULE__
    |> build()
    |> put_int(0x1)
    |> put_int(map_id)
    |> put_byte(0x1)
  end
end
