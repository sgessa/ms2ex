defmodule Ms2ex.Packets.StorageInventory do
  @moduledoc """
  Bank storage window packets: the item rows of the account storage, its
  stored mesos, slot expansion and errors.
  """

  alias Ms2ex.Enums
  alias Ms2ex.Packets

  import Ms2ex.Packets.PacketWriter

  @commands %{
    add: 0x0,
    remove: 0x1,
    move: 0x2,
    update_mesos: 0x3,
    slots_used: 0x4,
    load: 0x5,
    reload: 0x8,
    update: 0x9,
    reset: 0xB,
    slots_expanded: 0xD,
    open_dialog: 0xE,
    error: 0x10
  }

  def add(%{} = item, character) do
    __MODULE__
    |> build()
    |> put_byte(@commands.add)
    |> put_long()
    |> put_int(item.item_id)
    |> put_long(item.id)
    |> put_short(item.inventory_slot)
    |> put_int(item.rarity)
    |> Packets.InventoryItem.put_item(item, character)
  end

  def remove(uid) do
    __MODULE__
    |> build()
    |> put_byte(@commands.remove)
    |> put_long()
    |> put_long(uid)
  end

  def move(dst_uid, src_slot, src_uid, dst_slot) do
    __MODULE__
    |> build()
    |> put_byte(@commands.move)
    |> put_long()
    |> put_long(dst_uid)
    |> put_short(src_slot)
    |> put_long(src_uid)
    |> put_short(dst_slot)
  end

  def update_mesos(mesos) do
    __MODULE__
    |> build()
    |> put_byte(@commands.update_mesos)
    |> put_long(mesos)
  end

  def slots_used(count) do
    __MODULE__
    |> build()
    |> put_byte(@commands.slots_used)
    |> put_long()
    |> put_short(count)
  end

  def load(items, character) do
    __MODULE__ |> build() |> put_items(@commands.load, items, character)
  end

  def update(uid, remaining) do
    __MODULE__
    |> build()
    |> put_byte(@commands.update)
    |> put_long()
    |> put_long(uid)
    |> put_int(remaining)
  end

  def reset do
    __MODULE__
    |> build()
    |> put_byte(@commands.reset)
  end

  def slots_expanded(expansion) do
    __MODULE__
    |> build()
    |> put_byte(@commands.slots_expanded)
    |> put_int(expansion)
  end

  def open_dialog do
    __MODULE__
    |> build()
    |> put_byte(@commands.open_dialog)
  end

  def error(error) do
    __MODULE__
    |> build()
    |> put_byte(@commands.error)
    |> put_int(Enums.StorageError.get_value(error))
  end

  defp put_items(packet, command, items, character) do
    packet
    |> put_byte(command)
    |> put_long()
    |> put_short(length(items))
    |> reduce(items, fn item, packet ->
      packet
      |> put_int(item.item_id)
      |> put_long(item.id)
      |> put_short(item.inventory_slot)
      |> put_int(item.rarity)
      |> Packets.InventoryItem.put_item(item, character)
    end)
  end
end
