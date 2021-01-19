defmodule Ms2ex.Packets.ResponseTimeSync do
  import Ms2ex.Packets.PacketWriter

  def init(mode, tick) when mode == 0x1 or mode == 0x2 do
    __MODULE__
    |> build()
    |> put_byte(mode)
    |> put_int(tick)
    |> put_time(DateTime.utc_now())
    |> put_byte()
    |> put_int()
  end

  def init(0x3 = mode, _tick) do
    __MODULE__
    |> build()
    |> put_byte(mode)
    |> put_time(DateTime.utc_now())
  end
end
