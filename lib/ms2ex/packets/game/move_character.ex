defmodule Ms2ex.Packets.MoveCharacter do
  import Ms2ex.Packets.PacketWriter

  def bytes(character, position) do
    __MODULE__
    |> build()
    |> put_int(character.object_id)
    |> put_coord(position)
    |> put_int()
    |> put_int()
    |> put_int()
    |> put_byte()
  end
end
