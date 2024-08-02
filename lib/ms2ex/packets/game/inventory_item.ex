defmodule Ms2ex.Packets.InventoryItem do
  alias Ms2ex.{Enums, Schema, Types}

  import Ms2ex.Packets.PacketWriter

  @modes %{
    add: 0x0,
    remove: 0x1,
    update: 0x2,
    move: 0x3,
    mark_item_new: 0x8,
    load_items: 0xA,
    expand_tab: 0xC,
    load_tab: 0xE,
    reset_tab: 0xD
  }

  def add_item({:create, item}) do
    __MODULE__
    |> build()
    |> put_byte(@modes.add)
    |> put_int(item.item_id)
    |> put_long(item.id)
    |> put_short(item.inventory_slot)
    |> put_int(item.rarity)
    |> put_ustring()
    |> put_item(item)
    |> put_ustring()
  end

  def add_item({:update, item}), do: update_item(item.id, item.amount)

  def mark_item_new(item) do
    __MODULE__
    |> build()
    |> put_byte(@modes.mark_item_new)
    |> put_long(item.id)
    |> put_int(item.amount)
    |> put_ustring()
  end

  def consume({:delete, item}), do: remove_item(item.id)
  def consume({:update, item}), do: update_item(item.id, item.amount)

  def remove_item(uid) do
    __MODULE__
    |> build()
    |> put_byte(@modes.remove)
    |> put_long(uid)
  end

  def update_item(uid, amount) do
    __MODULE__
    |> build()
    |> put_byte(@modes.update)
    |> put_long(uid)
    |> put_int(amount)
  end

  def move_item(dst_uid, src_slot, src_uid, dst_slot) do
    __MODULE__
    |> build()
    |> put_byte(@modes.move)
    |> put_long(dst_uid)
    |> put_short(src_slot)
    |> put_long(src_uid)
    |> put_short(dst_slot)
  end

  def put_equips(packet, []), do: packet

  def put_equips(packet, [item | equips]) do
    packet
    |> put_int(item.item_id)
    |> put_long(item.id)
    |> put_ustring(to_string(item.equip_slot))
    |> put_int(item.rarity)
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
    |> put_bool(false)
    # TODO gacha dismantle id
    |> put_int()
    |> put_appearance(item)
    |> put_item_stats(item)
    |> put_int(item.enchant_level)
    |> put_int(item.enchant_exp)
    |> put_bool(true)
    |> put_long()
    |> put_int()
    |> put_int()
    |> put_bool(item.can_repackage)
    |> put_int(item.charges)
    |> put_item_enchant_stats(item)
    # |> put_template(item)
    # TODO put pets
    # TODO put gem slot
    |> put_int(item.transfer_flags)
    |> put_byte()
    |> put_int()
    |> put_int()
    |> put_byte()
    |> put_byte()
    |> put_bool(false)
    # TODO handle if char bound
    |> put_sockets()
    |> put_long(item.paired_character_id)
    # TODO put paired character name if present
    |> put_long()
    |> put_ustring("")
  end

  def load_items(tab_id, items) do
    __MODULE__
    |> build()
    |> put_byte(@modes.load_items)
    |> put_int(Enums.InventoryTab.get_value(tab_id))
    |> put_short(length(items))
    |> reduce(items, fn item, packet ->
      packet
      |> put_int(item.item_id)
      |> put_long(item.id)
      |> put_short(item.inventory_slot)
      |> put_int(item.rarity)
      |> put_item(item)
    end)
  end

  def expand_tab() do
    __MODULE__
    |> build()
    |> put_byte(@modes.expand_tab)
  end

  def load_tab(tab_id, total_slots) do
    __MODULE__
    |> build()
    |> put_byte(@modes.load_tab)
    |> put_byte(Enums.InventoryTab.get_value(tab_id))
    |> put_int(Schema.InventoryTab.extra_slots(tab_id, total_slots))
  end

  def reset_tab(tab_id) do
    __MODULE__
    |> build()
    |> put_byte(@modes.reset_tab)
    |> put_int(Enums.InventoryTab.get_value(tab_id))
  end

  defp put_appearance(packet, item) do
    packet =
      packet
      |> Types.ItemColor.put_item_color(item.color)
      |> put_int(item.appearance_flag)

    case item.equip_slot do
      :CP -> put_bytes(packet, String.duplicate(<<0x0>>, 13))
      :FD -> put_bytes(packet, item.data)
      :HR -> Types.Hair.put_hair(packet, item.data)
      _ -> packet
    end
  end

  defp put_item_stats(packet, item) do
    constant_basic_stats = Enum.filter(item.stats.constants, &(elem(&1, 1).class == :basic))
    constant_special_stats = Enum.filter(item.stats.constants, &(elem(&1, 1).class == :special))
    static_basic_stats = Enum.filter(item.stats.statics, &(elem(&1, 1).class == :basic))
    static_special_stats = Enum.filter(item.stats.statics, &(elem(&1, 1).class == :special))
    random_basic_stats = Enum.filter(item.stats.randoms, &(elem(&1, 1).class == :basic))
    random_special_stats = Enum.filter(item.stats.randoms, &(elem(&1, 1).class == :special))

    packet
    |> put_byte()
    |> put_short(Enum.count(constant_basic_stats))
    |> reduce(constant_basic_stats, fn {_, stat}, packet ->
      put_item_stat(packet, stat)
    end)
    |> put_short(Enum.count(constant_special_stats))
    |> reduce(constant_special_stats, fn {_, stat}, packet ->
      put_item_stat(packet, stat)
    end)
    |> put_int()
    |> put_short(Enum.count(static_basic_stats))
    |> reduce(static_basic_stats, fn {_, stat}, packet ->
      put_item_stat(packet, stat)
    end)
    |> put_short(Enum.count(static_special_stats))
    |> reduce(static_special_stats, fn {_, stat}, packet ->
      put_item_stat(packet, stat)
    end)
    |> put_int()
    |> put_short(Enum.count(random_basic_stats))
    |> reduce(random_basic_stats, fn {_, stat}, packet ->
      put_item_stat(packet, stat)
    end)
    |> put_short(Enum.count(random_special_stats))
    |> reduce(random_special_stats, fn {_, stat}, packet ->
      put_item_stat(packet, stat)
    end)
    |> put_int()
    |> reduce(1..6, fn _, packet ->
      packet
      |> put_short()
      |> put_short()
      |> put_int()
    end)
  end

  defp put_item_enchant_stats(packet, item) do
    enchant_stats = Enum.filter(item.stats.enchants, &(elem(&1, 1).class == :basic))

    basic_limit_break_enchants =
      Enum.filter(item.stats.limit_break_enchants, &(elem(&1, 1).class == :basic))

    special_limit_break_enchants =
      Enum.filter(item.stats.limit_break_enchants, &(elem(&1, 1).class == :special))

    packet
    |> put_byte(Enum.count(enchant_stats))
    |> reduce(enchant_stats, fn {_, stat}, packet ->
      put_item_stat(packet, stat)
    end)
    |> put_int(item.limit_break_level)
    |> put_int(Enum.count(basic_limit_break_enchants))
    |> reduce(basic_limit_break_enchants, fn {_, stat}, packet -> put_item_stat(packet, stat) end)
    |> put_int(Enum.count(special_limit_break_enchants))
    |> reduce(special_limit_break_enchants, fn {_, stat}, packet ->
      put_item_stat(packet, stat)
    end)
  end

  defp put_item_stat(packet, %{class: :basic} = stat) do
    packet
    |> put_short(Enums.BasicStatType.get_value(stat.attribute))
    |> put_int(Types.ItemStat.flat_value(stat))
    |> put_float(Types.ItemStat.rate_value(stat))
  end

  defp put_item_stat(packet, %{class: :special} = stat) do
    packet
    |> put_short(Enums.SpecialStatType.get_value(stat.attribute))
    |> put_float(Types.ItemStat.rate_value(stat))
    |> put_float(Types.ItemStat.flat_value(stat))
  end

  defp put_sockets(packet) do
    sockets_length = 0

    packet
    |> put_byte()
    |> put_byte(sockets_length)
  end
end
