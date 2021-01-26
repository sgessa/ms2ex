defmodule Ms2ex.Packets.FieldRemoveUser do
  import Ms2ex.Packets.PacketWriter

  def bytes(character) do
    __MODULE__
    |> build()
    |> put_int(character.object_id)
  end
end
