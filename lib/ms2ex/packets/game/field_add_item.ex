defmodule Ms2ex.Packets.FieldAddItem do
  alias Ms2ex.Packets

  import Packets.PacketWriter

  def add_item(item) do
    __MODULE__
    |> build()
    |> put_int(item.object_id)
    |> put_int(item.item_id)
    |> put_int(item.amount)
    |> put_bool(true)
    |> put_long(item.lock_character_id)
    |> put_coord(item.position)
    |> put_int(item.source_object_id)
    |> put_int()
    |> put_byte(0x2)
    |> put_int(item.rarity)
    |> put_short(1005)
    |> put_byte()
    |> put_byte()
    |> Packets.InventoryItem.put_item(item)
  end

  def add_mob_drop(item) do
    __MODULE__
    |> build()
    |> put_int(item.object_id)
    |> put_int(item.item_id)
    |> put_int(item.amount)
    |> put_byte(0x1)
    |> put_long(item.lock_character_id)
    |> put_coord(item.position)
    |> put_int(item.source_object_id)
    |> put_int()
    |> put_byte()
    |> put_int(item.rarity)
    |> put_int(21)
    |> put_special_item_data(item)
  end

  defp put_special_item_data(packet, %{item_id: id} = item)
       when id >= 90_000_004 and id <= 90_000_011 do
    packet
    |> put_int(1)
    |> put_int()
    |> put_int(-1)
    |> put_int(item.target_object_id)
    |> reduce(1..14, fn _, packet -> put_int(packet) end)
    |> put_int(-1)
    |> reduce(1..24, fn _, packet -> put_int(packet) end)
    |> put_int()
    |> put_short()
    |> put_int(1)
    |> put_int()
    |> put_int()
    |> put_int()
    |> put_short()
    |> put_int(6)
    |> put_int()
    |> put_int()
    |> put_short()
    |> put_int(1)
    |> put_int()
    |> put_int()
    |> put_int()
    |> put_int()
    |> put_short()
  end

  defp put_special_item_data(packet, _item), do: packet
end
