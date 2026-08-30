defmodule Ms2ex.Packets.DeadUser do
  import Ms2ex.Packets.PacketWriter

  # broadcasts a player death; the client plays the death animation and shows
  # the tomb. dark_tomb marks a repeat death (metal tomb) vs the first one.
  def bytes(object_id, dark_tomb) do
    __MODULE__
    |> build()
    |> put_int(object_id)
    |> put_bool(dark_tomb)
  end
end
