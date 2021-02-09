defmodule Ms2ex.Packets.FieldPickupItem do
  alias Ms2ex.Packets

  import Packets.PacketWriter

  def bytes(character, item) do
    __MODULE__
    |> build()
    |> put_byte(0x1)
    |> put_int(item.object_id)
    |> put_int(character.object_id)
  end
end
