defmodule Ms2ex.Packets.Revival do
  import Ms2ex.Packets.PacketWriter

  # broadcast to the field when a player revives; the trailing byte is a
  # revive-mode flag the client reads as a no-op
  def bytes(object_id) do
    __MODULE__
    |> build()
    |> put_int(object_id)
    |> put_byte()
  end
end
