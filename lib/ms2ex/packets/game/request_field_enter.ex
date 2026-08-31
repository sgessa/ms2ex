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
    # session field key the client validates on enter; a wrong value makes the
    # client reject the field state without any visible error
    |> put_int(0x1234)
  end
end
