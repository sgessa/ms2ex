defmodule Ms2ex.Packets.MarketInventory do
  import Ms2ex.Packets.PacketWriter

  @modes %{start_list: 0x1, count: 0x2, end_list: 0x8}

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

  def count(n) do
    __MODULE__
    |> build()
    |> put_byte(@modes.count)
    |> put_int(n)
  end
end
