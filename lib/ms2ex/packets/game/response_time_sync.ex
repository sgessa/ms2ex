defmodule Ms2ex.Packets.ResponseTimeSync do
  import Ms2ex.Packets.PacketWriter

  # direct reply to the client's time-sync request: carries the server's
  # wall-clock tick so the client can lock its server<->client offset
  def response(tick, unix, offset_seconds, timezone, key) do
    __MODULE__
    |> build()
    |> put_byte(0x0)
    |> put_int(tick)
    |> put_long(unix)
    |> put_int(offset_seconds)
    |> put_byte(timezone)
    |> put_int(key)
  end

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
