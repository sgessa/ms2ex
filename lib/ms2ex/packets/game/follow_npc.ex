defmodule Ms2ex.Packets.FollowNpc do
  import Ms2ex.Packets.PacketWriter

  # makes the client auto-walk the player, following an npc — used by
  # scripted carry sequences
  def follow(npc_object_id) do
    __MODULE__
    |> build()
    |> put_int(npc_object_id)
  end
end
