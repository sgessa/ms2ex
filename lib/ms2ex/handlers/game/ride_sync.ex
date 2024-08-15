defmodule Ms2ex.GameHandlers.RideSync do
  alias Ms2ex.{Managers, Packets, Types, Context}

  import Packets.PacketReader

  def handle(packet, session) do
    {_mode, packet} = get_byte(packet)

    {_server_tick, packet} = get_int(packet)
    {_client_tick, packet} = get_int(packet)
    {segment_length, packet} = get_byte(packet)

    process_segments(session, segment_length, packet)
  end

  defp process_segments(session, segment_length, packet) when segment_length > 0 do
    {:ok, character} = Managers.Character.lookup(session.character_id)

    {sync_states, _packet} = get_sync_states(segment_length, packet)

    sync_packet = Packets.RideSync.bytes(character, sync_states)
    Context.Field.broadcast_from(character, sync_packet, session.pid)
  end

  defp process_segments(_session, _segment_length, packet), do: packet

  defp get_sync_states(segment_count, packet) do
    Enum.reduce(1..segment_count, {[], packet}, fn _, {sync_states, packet} ->
      {sync_state, packet} = Types.SyncState.from_packet(packet)
      {_client_tick, packet} = get_int(packet)
      {_server_tick, packet} = get_int(packet)

      {sync_states ++ [sync_state], packet}
    end)
  end
end
