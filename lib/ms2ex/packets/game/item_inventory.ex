defmodule Ms2ex.Packets.ItemInventory do
  alias Ms2ex.InventoryItems.Item

  import Ms2ex.Packets.PacketWriter

  @modes %{add: 0x0, load: 0xE, reset: 0xD}

  def add_item({:ok, {:create, item}}) do
    slot_type = Keyword.get(Item.SlotType.__enum_map__(), item.slot_type)

    __MODULE__
    |> build()
    |> put_byte(@modes.add)
    |> put_int(item.item_id)
    |> put_long(item.id)
    |> put_short(slot_type)
    |> put_int(item.rarity)
    |> put_ustring()
    |> put_item(item)
  end

  def add_item({:ok, {:update, _item, _new_amount}}), do: ""

  def put_equips(packet, []), do: packet

  def put_equips(packet, [item | equips]) do
    packet
    |> put_int(item.item_id)
    |> put_long(item.id)
    |> put_ustring(Item.slot_name(item.slot_type))
    |> put_int(1)
    |> put_item(item)
    |> put_equips(equips)
  end

  def put_item(packet, item) do
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
    |> put_byte()
    |> put_int()
    |> put_appearance(item)
    |> put_item_stats(item)
    |> put_int(item.enchants)
    |> put_int(item.enchant_exp)
    |> put_bool(true)
    |> put_long()
    |> put_int()
    |> put_int()
    |> put_bool(item.can_repackage)
    |> put_int(item.charges)
    |> put_item_stats_diff(item)
    # TODO write template if is_template
    # TODO write pets
    |> put_int(item.transfer_flag)
    |> put_byte()
    |> put_int()
    |> put_int()
    |> put_byte()
    |> put_byte(1)
    |> put_bool(false)
    |> put_byte()
    |> put_sockets()
    |> put_long(item.paired_character_id)
    |> put_long()
    |> put_ustring("")
  end

  def put_appearance(packet, item) do
    packet =
      packet
      |> Ms2ex.ItemColor.put_item_color(item.color)
      |> put_int(item.appearance_flag)

    case item.slot_type do
      :face_decor -> put_bytes(packet, item.data)
      :hair -> Item.Hair.put_hair(packet, item.data)
      _ -> packet
    end
    |> put_byte()
  end

  def put_item_stats(packet, _item) do
    packet
    |> put_short(0)
    # TODO put basic attrs
    |> put_short()
    |> put_int()
    |> put_short()
    |> put_short()
    |> put_int()
    |> put_short(0)
    # TODO put bonus attrs
    |> put_short()
    |> put_int()
    |> reduce(1..6, fn _, packet ->
      packet
      |> put_short()
      |> put_short()
      |> put_int()
    end)
  end

  def put_item_stats_diff(packet, _item) do
    packet
    |> put_byte(0)
    |> put_int()
    |> put_int(0)
    |> put_int(0)
  end

  def put_sockets(packet) do
    packet
    |> put_byte(0)
  end

  def load({_name, id}) do
    __MODULE__
    |> build()
    |> put_byte(@modes.load)
    |> put_byte(id)
    |> put_int()
  end

  def reset({_name, id}) do
    __MODULE__
    |> build()
    |> put_byte(@modes.reset)
    |> put_int(id)
  end
end
