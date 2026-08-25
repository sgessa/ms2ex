defmodule Ms2ex.GameHandlers.RideSync do
  alias Ms2ex.Managers
  alias Ms2ex.Packets
  alias Ms2ex.Types
  alias Ms2ex.Context

  import Packets.PacketReader

  # riders report walk while mounted; relabel so other clients render the
  # mounted animation instead of walking legs
  @walk_state 2
  @ride_state 33

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
    Context.Field.broadcast_from(character, sync_packet, session.sender_pid)
  end

  defp process_segments(_session, _segment_length, packet), do: packet

  defp get_sync_states(segment_count, packet) do
    Enum.reduce(1..segment_count, {[], packet}, fn _, {sync_states, packet} ->
      {sync_state, packet} = Types.SyncState.from_packet(packet)
      sync_state = maybe_relabel_ride(sync_state)
      {_client_tick, packet} = get_int(packet)
      {_server_tick, packet} = get_int(packet)

      {sync_states ++ [sync_state], packet}
    end)
  end

  defp maybe_relabel_ride(%{state: @walk_state} = sync_state) do
    %{sync_state | state: @ride_state}
  end

  defp maybe_relabel_ride(sync_state), do: sync_state
end
