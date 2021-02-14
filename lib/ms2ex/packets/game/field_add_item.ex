defmodule Ms2ex.Packets.FieldAddItem do
  alias Ms2ex.Packets

  import Packets.PacketWriter

  def bytes(item) do
    IO.inspect(item)

    __MODULE__
    |> build()
    |> put_int(item.object_id)
    |> put_int(item.item_id)
    |> put_int(item.amount)
    |> put_bool(true)
    |> put_long()
    |> put_coord(item.position)
    |> put_int(item.character_object_id)
    |> put_int()
    |> put_byte(0x2)
    |> put_int(item.rarity)
    |> put_short(1005)
    |> put_byte()
    |> put_byte()
    |> Packets.InventoryItem.put_item(item)
  end
end
