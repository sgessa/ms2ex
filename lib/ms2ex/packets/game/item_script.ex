defmodule Ms2ex.Packets.ItemScript do
  import Ms2ex.Packets.PacketWriter

  def lullu_box(items), do: box(0x0, items)
  def gacha(items), do: box(0x5, items)

  defp box(packet_type, items) do
    __MODULE__
    |> build()
    |> put_byte(packet_type)
    |> put_int(length(items))
    |> reduce(items, fn item, packet ->
      packet
      |> put_int(item.item_id)
      |> put_int(item.amount)
      |> put_int(item.rarity)
      |> put_bool(true)
    end)
  end
end
