defmodule Ms2ex.Packets.ItemUse do
  import Ms2ex.Packets.PacketWriter

  def expand_inventory do
    __MODULE__
    |> build()
    |> put_byte(0x0)
  end

  def max_inventory do
    __MODULE__
    |> build()
    |> put_byte(0x1)
  end

  def quest_scroll(item_id) do
    __MODULE__
    |> build()
    |> put_byte(0x4)
    |> put_int(item_id)
  end
end
