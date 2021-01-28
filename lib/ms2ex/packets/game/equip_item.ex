defmodule Ms2ex.Packets.EquipItem do
  alias Ms2ex.Packets

  import Packets.PacketWriter

  def bytes(character, item) do
    __MODULE__
    |> build()
    |> put_int(character.object_id)
    |> put_int(item.item_id)
    |> put_long(item.id)
    |> put_ustring(to_string(item.metadata.slot))
    |> put_int(item.metadata.rarity)
    |> put_byte()
    |> Packets.ItemInventory.put_item(item)
  end
end
