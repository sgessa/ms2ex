defmodule Ms2ex.Packets.RideSync do
  alias Ms2ex.SyncState

  import Ms2ex.Packets.PacketWriter

  def bytes(character, sync_states) do
    __MODULE__
    |> build()
    |> put_int(character.object_id)
    |> put_byte(length(sync_states))
    |> reduce(sync_states, &SyncState.put_state(&2, &1))
  end
end
