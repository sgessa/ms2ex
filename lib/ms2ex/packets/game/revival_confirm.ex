defmodule Ms2ex.Packets.RevivalConfirm do
  import Ms2ex.Packets.PacketWriter

  def bytes(object_id, end_tick, count \\ 0) do
    __MODULE__
    |> build()
    |> put_int(object_id)
    |> put_int(end_tick)
    |> put_int(count)
  end
end
