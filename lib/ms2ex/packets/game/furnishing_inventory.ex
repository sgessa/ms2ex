defmodule Ms2ex.Packets.FurnishingInventory do
  import Ms2ex.Packets.PacketWriter

  @modes %{start_list: 0x0, end_list: 0x4}

  def start_list() do
    __MODULE__
    |> build()
    |> put_byte(@modes.start_list)
  end

  def end_list() do
    __MODULE__
    |> build()
    |> put_byte(@modes.end_list)
  end
end
