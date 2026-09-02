defmodule Ms2ex.Packets.FieldAddItem do
  alias Ms2ex.Packets
  alias Ms2ex.TransferFlags

  import Packets.PacketWriter

  def add_item(%{mob_drop?: false} = item) do
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

    put_item_class(packet, item)
  end

  def add_item(item) do
    packet =
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
      |> put_byte(0x2)
      |> put_int(item.rarity)
      |> put_short(0)
      |> put_bool(false)
      |> put_bool(false)

    put_mob_drop_item_class(packet, item)
  end

  # meso drops carry no item payload; the currency family uses the legacy
  # blob; every other dropped item is serialized in full so the client can
  # render it on the field
  defp put_mob_drop_item_class(packet, %{item_id: id}) when id in 90_000_001..90_000_003,
    do: packet

  defp put_mob_drop_item_class(packet, %{item_id: id} = item) when id in 90_000_004..90_000_011,
    do: put_special_item_data(packet, item)

  defp put_mob_drop_item_class(packet, item), do: put_item_class(packet, item)

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

  # serializes a freshly dropped (default) item; every section is written in
  # its default state
  defp put_item_class(packet, item) do
    packet
    |> put_int(item.amount)
    |> put_int()
    |> put_int(-1)
    |> put_time(item.inserted_at)
    |> put_time(item.expires_at)
    |> put_long()
    |> put_int(item.times_attr_changed)
    |> put_int()
    |> put_bool(item.is_locked)
    |> put_time(item.unlocks_at)
    |> put_short(item.glamor_forges_left)
    |> put_bool(false)
    |> put_int()
    # appearance: equip color with primary/secondary/tertiary zeros,
    # index = -1, palette id = 0
    |> put_bytes(<<0::size(96)>>)
    |> put_int(-1)
    |> put_int()
    # stats: byte 0 + 9 x (basic count = 0, special count = 0, int 0)
    |> put_byte()
    |> reduce(1..9, fn _, packet ->
      packet
      |> put_short()
      |> put_short()
      |> put_int()
    end)
    # enchant: charges = 1, tradeable = true, no basic options
    |> put_int()
    |> put_int()
    |> put_byte(1)
    |> put_long()
    |> put_int()
    |> put_int()
    |> put_bool(true)
    |> put_int()
    |> put_byte()
    # limit break: level 0, empty option lists
    |> put_int()
    |> put_int()
    |> put_int()
    # transfer: item trade state, no binding, socket transfer bit set
    |> put_int(TransferFlags.to_int(item.transfer_flags))
    |> put_bool(false)
    |> put_int(item.remaining_trades)
    |> put_int()
    |> put_byte()
    |> put_bool(true)
    |> put_bool(false)
    # sockets: max slots 0, unlock slots 0
    |> put_byte()
    |> put_byte()
    # couple info: character id 0 skips the name block
    |> put_long()
    # binding info
    |> put_long()
    |> put_ustring("")
    # trailing zero padding: consumption buffer, same rationale as above
    |> reduce(1..64, fn _, packet -> put_int(packet) end)
  end
end
