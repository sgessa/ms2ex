defmodule Ms2ex.Packets.FieldAddItem do
  @behaviour Ms2ex.Packets.Spec

  alias Ms2ex.Packets
  alias Ms2ex.Packets.PacketReader

  import Packets.PacketWriter

  @impl true
  def spec(_command) do
    [
      object_id: :int,
      item_id: :int,
      amount: :int,
      # receiver flag + optional lock long, position, source actor, drop
      # type, rarity, trailing flags; the item class body is consumed whole
      # (its byte size reported) — it is the full shared item serialization
      drop: fn packet -> decode_drop_fields(packet) end
    ]
  end

  defp decode_drop_fields(packet) do
    {receiver?, packet} = PacketReader.get_bool(packet)

    {lock, packet} =
      if receiver?, do: PacketReader.get_long(packet), else: {0, packet}

    {position, packet} = PacketReader.get_coord(packet)
    {source_object_id, packet} = PacketReader.get_int(packet)
    {_unknown, packet} = PacketReader.get_int(packet)
    {drop_type, packet} = PacketReader.get_byte(packet)
    {rarity, packet} = PacketReader.get_int(packet)
    {_short, packet} = PacketReader.get_short(packet)
    {_fixed, packet} = PacketReader.get_bool(packet)
    {_flag, packet} = PacketReader.get_bool(packet)

    fields = %{
      locked?: receiver?,
      lock: lock,
      position: position,
      source_object_id: source_object_id,
      drop_type: drop_type,
      rarity: rarity,
      item_class_bytes: byte_size(packet)
    }

    {fields, <<>>}
  end

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
