defmodule Ms2ex.Packets.RequestFieldEnter do
  import Ms2ex.Packets.PacketWriter

  def bytes(map_id, position, rotation) do
    __MODULE__
    |> build()
    |> put_byte(0x0)
    |> put_int(map_id)
    |> put_byte()
    |> put_byte()
    |> put_int()
    |> put_int()
    |> put_coord(position)
    |> put_coord(rotation)
    |> put_int()
  end
end
