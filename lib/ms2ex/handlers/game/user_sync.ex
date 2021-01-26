defmodule Ms2ex.GameHandlers.UserSync do
  alias Ms2ex.{Field, Packets, Registries, SyncState}

  import Packets.PacketReader

  def handle(packet, %{character_id: character_id} = session) do
    {_mode, packet} = get_byte(packet)

    {client_tick, packet} = get_int(packet)
    {_server_tick, packet} = get_int(packet)
    {segments, packet} = get_byte(packet)

    if segments > 0 do
      {:ok, character} = Registries.Characters.lookup(character_id)
      states = get_states(segments, packet)

      sync_packet = Packets.UserSync.bytes(character, states)
      Field.broadcast(character.field_pid, sync_packet, session.pid)

      first_state = List.first(states)

      character
      |> Map.put(:animation, first_state.animation1)
      |> Map.put(:position, first_state.position)
      |> Registries.Characters.update()
    end

    %{session | client_tick: client_tick}
  end

  defp get_states(segments, packet, state \\ [])

  defp get_states(segments, packet, states) when segments > 0 do
    {sync_state, packet} = SyncState.from_packet(packet)
    {_client_tick, packet} = get_int(packet)
    {_server_tick, packet} = get_int(packet)
    get_states(segments - 1, packet, states ++ [sync_state])
  end

  defp get_states(_segments, _packet, states), do: states
end
