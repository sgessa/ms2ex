defmodule Ms2ex.Packets.BadgeEquip do
  alias Ms2ex.Enums
  alias Ms2ex.Packets
  alias Ms2ex.Types

  import Packets.PacketWriter

  def equip(character, item) do
    __MODULE__
    |> build()
    |> put_byte(0x0)
    |> put_int(character.object_id)
    |> put_int(item.item_id)
    |> put_long(item.id)
    |> put_int(item.rarity)
    |> put_byte(Enums.BadgeType.get_value(Types.Item.badge_type(item.item_id)))
    |> Packets.InventoryItem.put_item(item, character)
  end

  def unequip(character, badge_type) do
    __MODULE__
    |> build()
    |> put_byte(0x1)
    |> put_int(character.object_id)
    |> put_byte(Enums.BadgeType.get_value(badge_type))
  end
end
