defmodule Ms2ex.Packets.UserMoveByPortal do
  import Ms2ex.Packets.PacketWriter

  def bytes(character) do
    __MODULE__
    |> build()
    |> put_int(character.object_id)
    |> put_coord(character.safe_position)
    |> put_int()
    |> put_int()
    |> put_int()
    |> put_byte()
  end
end
