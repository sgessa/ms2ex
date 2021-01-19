defmodule Ms2ex.GameHandlers.UserSync do
  alias Ms2ex.{Field, Packets, SyncState}

  import Packets.PacketReader

  def handle(packet, %{character: character} = session) do
    {_mode, packet} = get_byte(packet)

    {client_tick, packet} = get_int(packet)
    {server_tick, packet} = get_int(packet)
    {segments, packet} = get_tiny(packet)

    states = get_states(segments, packet)
    sync_packet = Packets.UserSync.bytes(character, states)
    Field.broadcast(session.field_pid, sync_packet, character.id)

    %{session | client_tick: client_tick, server_tick: server_tick}
  end

  defp get_states(segments, packet, state \\ [])

  defp get_states(segments, packet, states) when segments > 0 do
    sync_state = SyncState.from_packet(packet)

    # Client Ticks
    {_, packet} = get_int(packet)

    # Server Ticks
    {_, packet} = get_int(packet)

    get_states(segments - 1, packet, states ++ [sync_state])
  end

  defp get_states(_segments, _packet, states), do: states
end
