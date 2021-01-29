defmodule Ms2ex.Packets.RequestFieldEnter do
  import Ms2ex.Packets.PacketWriter

  # TODO
  @spawn_coords {-39, -4347, 9001}

  def bytes(character) do
    __MODULE__
    |> build()
    |> put_byte(0x0)
    |> put_int(character.map_id)
    |> put_byte()
    |> put_byte()
    |> put_int()
    |> put_int()
    |> put_coord(@spawn_coords)
    |> put_coord(character.rotation)
    |> put_int()
  end
end
