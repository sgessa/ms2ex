defmodule Ms2ex.Packets.UnequipItem do
  import Ms2ex.Packets.PacketWriter

  def bytes(character, item_uid) do
    __MODULE__
    |> build()
    |> put_int(character.object_id)
    |> put_long(item_uid)
  end
end
