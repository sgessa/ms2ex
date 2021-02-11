defmodule Ms2ex.Packets.EquipItem do
  alias Ms2ex.Packets

  import Packets.PacketWriter

  def bytes(character, item) do
    __MODULE__
    |> build()
    |> put_int(character.object_id)
    |> put_int(item.item_id)
    |> put_long(item.id)
    |> put_ustring(to_string(item.equip_slot))
    |> put_int(item.rarity)
    |> put_byte()
    |> Packets.InventoryItem.put_item(item)
  end
end
