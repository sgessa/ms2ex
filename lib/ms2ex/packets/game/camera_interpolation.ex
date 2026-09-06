defmodule Ms2ex.Packets.CameraInterpolation do
  import Ms2ex.Packets.PacketWriter

  # returns the camera from a scripted path back to the player view
  def interpolate(time) do
    __MODULE__
    |> build()
    |> put_float(time)
  end
end
