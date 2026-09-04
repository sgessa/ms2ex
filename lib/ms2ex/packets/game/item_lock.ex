defmodule Ms2ex.Packets.ItemLock do
  alias Ms2ex.Packets

  import Packets.PacketWriter

  @modes %{stage: 0x01, unstage: 0x02, commit: 0x03, error: 0x04}

  def stage(item_uid, index) do
    __MODULE__
    |> build()
    |> put_byte(@modes.stage)
    |> put_long(item_uid)
    |> put_short(index)
  end

  def unstage(item_uid) do
    __MODULE__
    |> build()
    |> put_byte(@modes.unstage)
    |> put_long(item_uid)
  end

  def commit(items, character) do
    __MODULE__
    |> build()
    |> put_byte(@modes.commit)
    |> put_byte(length(items))
    |> reduce(items, fn item, packet ->
      packet
      |> put_long(item.id)
      |> Packets.InventoryItem.put_item(item, character)
    end)
  end

  def error(code \\ 1) do
    __MODULE__
    |> build()
    |> put_byte(@modes.error)
    |> put_int(code)
  end
end
