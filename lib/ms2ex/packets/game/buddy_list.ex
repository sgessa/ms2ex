defmodule Ms2ex.Packets.BuddyList do
  import Ms2ex.Packets.PacketWriter

  @modes %{start_list: 0xF, end_list: 0x13}

  def start_list() do
    __MODULE__
    |> build()
    |> put_byte(@modes.start_list)
  end

  def end_list() do
    __MODULE__
    |> build()
    |> put_byte(@modes.end_list)
    |> put_int(0)
  end
end
