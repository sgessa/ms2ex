defmodule Ms2ex.GameHandlers.RideSync do
  alias Ms2ex.Context
  alias Ms2ex.Managers
  alias Ms2ex.Packets
  alias Ms2ex.Storage
  alias Ms2ex.Types

  import Packets.PacketReader

  # riders report walk while mounted; relabel so other clients render the
  # mounted animation instead of walking legs
  @walk_state 2
  @ride_state 33
  @swim_states [27, 28]

  # the smart push players buy to keep their mount in water
  @safe_water_riding "SafeWaterRiding"

  def handle(packet, session) do
    {_mode, packet} = get_byte(packet)

    {_server_tick, packet} = get_int(packet)
    {_client_tick, packet} = get_int(packet)
    {segment_length, packet} = get_byte(packet)

    process_segments(session, segment_length, packet)
  end

  defp process_segments(session, segment_length, packet) when segment_length > 0 do
    {:ok, character} = Managers.Character.call(session.character_id, :lookup)

    {sync_states, _packet} = get_sync_states(segment_length, packet)

    sync_packet = Packets.RideSync.bytes(character, sync_states)
    Context.Field.broadcast_from(character, sync_packet, session.sender_pid)

    unless dismount_in_water(character, sync_states) do
      track_riding_distance(character, sync_states)
    end
  end

  defp process_segments(_session, _segment_length, packet), do: packet

  # water throws the rider unless they paid to stay mounted
  defp dismount_in_water(%{mount: nil}, _sync_states), do: false

  defp dismount_in_water(character, sync_states) do
    if Enum.any?(sync_states, &(&1.state in @swim_states)) and not safe_water_riding?(character) do
      Managers.Character.call(character, {:update, %{character | mount: nil}})
      Context.Field.broadcast(character, Packets.ResponseRide.stop_ride(character, true))
      true
    else
      false
    end
  end

  defp safe_water_riding?(character) do
    case Storage.Tables.SmartPush.effect_id(@safe_water_riding) do
      nil -> false
      effect_id -> Context.Field.has_buff?(character, effect_id)
    end
  end

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

  defp track_riding_distance(%{mount: nil}, _sync_states), do: :ok

  defp track_riding_distance(character, sync_states) do
    positions = Enum.map(sync_states, & &1.position)

    case Map.get(character.mount, :last_position, character.position) do
      nil ->
        mount =
          Map.merge(character.mount, %{last_position: List.last(positions), ride_distance: 0})

        Managers.Character.call(character, {:update, %{character | mount: mount}})

      previous_position ->
        update_riding_distance(character, positions, previous_position)
    end
  end

  defp update_riding_distance(character, positions, previous_position) do
    {distance, last_position} =
      Enum.reduce(
        positions,
        {Map.get(character.mount, :ride_distance, 0), previous_position},
        fn position, {distance, previous} ->
          travelled = Context.MapBlock.subtract(position, previous) |> Context.MapBlock.length()
          {distance + travelled, position}
        end
      )

    block_size = Context.MapBlock.block_size()
    progress = trunc(distance / block_size)

    mount =
      Map.merge(character.mount, %{
        last_position: last_position,
        ride_distance: rem(trunc(distance), block_size)
      })

    character = %{character | mount: mount, position: last_position}
    Managers.Character.call(character, {:update, character})

    if progress > 0 do
      Managers.Quest.update_conditions(
        character.id,
        :riding,
        progress,
        "",
        0,
        "",
        character.map_id
      )
    end
  end
end
