defmodule Ms2ex.Packets.FieldAddItem do
  alias Ms2ex.Packets

  import Packets.PacketWriter

  # drop types: Default (0) auto-loots on walk-over — mob drops; Player (2)
  # is the reference's type for the captured pet's drop
  def add_item(item, character \\ nil)

  def add_item(%{mob_drop?: false} = item, character) do
    packet =
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
      |> put_short(0)
      |> put_bool(false)
      |> put_bool(false)

    put_item_class(packet, item, character)
  end

  def add_item(item, character) do
    packet =
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
      |> put_byte(0x0)
      |> put_int(item.rarity)
      |> put_short(0)
      |> put_bool(false)
      |> put_bool(false)

    put_mob_drop_item_class(packet, item, character)
  end

  # the captured pet's drop: DropType.Player with no receiver (the
  # reference spawns it unlocked), lootable by anyone walking over it
  def add_pet_drop(item) do
    packet =
      __MODULE__
      |> build()
      |> put_int(item.object_id)
      |> put_int(item.item_id)
      |> put_int(item.amount)
      |> put_bool(false)
      |> put_coord(item.position)
      |> put_int(item.source_object_id)
      |> put_int()
      |> put_byte(0x2)
      |> put_int(item.rarity)
      |> put_short(0)
      |> put_bool(false)
      |> put_bool(false)

    put_item_class(packet, item, nil)
  end

  defp put_mob_drop_item_class(packet, %{item_id: id}, _character)
       when id in 90_000_001..90_000_003,
       do: packet

  defp put_mob_drop_item_class(packet, %{item_id: id} = item, _character)
       when id in 90_000_004..90_000_011,
       do: put_special_item_data(packet, item)

  defp put_mob_drop_item_class(packet, item, character),
    do: put_item_class(packet, item, character)

  defp put_special_item_data(packet, %{item_id: id} = item)
       when id >= 90_000_004 and id <= 90_000_011 do
    packet
    |> put_int(1)
    |> put_int()
    |> put_int()
    |> put_int(item.target_object_id)
    |> reduce(1..14, fn _, packet -> put_int(packet) end)
    |> put_int()
    |> reduce(1..24, fn _, packet -> put_int(packet) end)
    |> put_int()
    |> put_short()
    |> put_int()
    |> put_int()
    |> put_int()
    |> put_int()
    |> put_short()
    |> put_int()
    |> put_int()
    |> put_int()
    |> put_short()
    |> put_int()
    |> put_int()
    |> put_int()
    |> put_int()
    |> put_int()
    |> put_short()
    # trailing zero padding: if the client expects more tail fields than we
    # write, it consumes these instead of the packets that follow on the wire
    |> reduce(1..64, fn _, packet -> put_int(packet) end)
  end

  defp put_special_item_data(packet, _item), do: packet

  # the item class is the full shared item serialization (the reference's
  # WriteClass<Item>): pet/badge/music-score items carry their template
  # block, without which the client cannot decode the drop
  defp put_item_class(packet, item, character) do
    Packets.InventoryItem.put_item(packet, item, character)
  end
end
