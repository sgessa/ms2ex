defmodule Ms2ex.Packets.TimeScale do
  import Ms2ex.Packets.PacketWriter

  # trigger scripts slow/speed up the field's tick rate for a cinematic
  # beat (e.g. a bullet-time dodge sequence): scale ramps from start to
  # end over duration seconds using the given interpolator, and enable
  # false reverts to normal speed
  def set(enable, start_scale, end_scale, duration, interpolator) do
    __MODULE__
    |> build()
    |> put_bool(enable)
    |> put_float(start_scale)
    |> put_float(end_scale)
    |> put_float(duration)
    |> put_byte(interpolator)
  end
end
