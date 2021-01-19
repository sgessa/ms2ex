defmodule Ms2ex.Packets.UserSync do
  alias Ms2ex.SyncState

  import Ms2ex.Packets.PacketWriter

  def bytes(character, sync_states) do
    __MODULE__
    |> build()
    |> put_int(character.object_id)
    |> put_byte(length(sync_states))
    |> put_states(sync_states)
  end

  defp put_states(packet, []), do: packet

  defp put_states(packet, [state | states]) do
    packet
    |> SyncState.put_state(state)
    |> put_states(states)
  end
end
