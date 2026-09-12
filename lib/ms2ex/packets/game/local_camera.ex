defmodule Ms2ex.Packets.LocalCamera do
  import Ms2ex.Packets.PacketWriter

  # attaches or releases a map camera vantage for the local player view
  # (script set_local_camera); the object id stays zero for map cameras
  def set(trigger_id, enable, object_id \\ 0) do
    __MODULE__
    |> build()
    |> put_int(trigger_id)
    |> put_bool(enable)
    |> put_int(object_id)
  end
end
