defmodule Ms2ex.GameHandlers.UserSync do
  alias Ms2ex.Managers
  alias Ms2ex.Context
  alias Ms2ex.Types
  alias Ms2ex.Storage
  alias Ms2ex.Packets
  alias Ms2ex.Constants

  import Packets.PacketReader
  import Ms2ex.Net.SenderSession, only: [push: 2]

  @ladder_state 8
  @rope_state 9
  @hold_state 32
  @walk_state 2
  @crawl_state 3
  @fall_state 5
  @swim_states [27, 28]
  @climb_state 29
  @glide_state 30

  def handle(packet, session) do
    {_unknown, packet} = get_byte(packet)
    {_server_ticks, packet} = get_int(packet)
    {_client_ticks, packet} = get_int(packet)

    {segment_length, packet} = get_byte(packet)

    process_segments(session, segment_length, packet)
  end

  defp process_segments(session, segment_length, packet) when segment_length > 0 do
    {:ok, character} = Managers.Character.call(session.character_id, :lookup)

    {sync_states, _packet} = get_sync_states(segment_length, packet)

    sync_packet = Packets.UserSync.bytes(character, sync_states)
    Context.Field.broadcast_from(character, sync_packet, session.sender_pid)

    Managers.Character.cast(
      character.id,
      {:set_time_condition, time_condition(List.first(sync_states).state)}
    )

    track_distance_condition(character, List.first(sync_states))

    ensure_safe_position(session, character, sync_states)
  end

  defp process_segments(_session, _segment_length, packet), do: packet

  defp get_sync_states(segment_count, packet) do
    Enum.reduce(1..segment_count, {[], packet}, fn _, {states, packet} ->
      {sync_state, packet} = Types.SyncState.from_packet(packet)
      {_client_tick, packet} = get_int(packet)
      {_server_tick, packet} = get_int(packet)

      {states ++ [sync_state], packet}
    end)
  end

  # TODO needs reworking, re-use in RideSync handler

  defp ensure_safe_position(session, character, sync_states) do
    %{state: state, position: new_position} = List.first(sync_states)
    closest_block = Context.MapBlock.closest_block(new_position)
    # Get the block under the character
    closest_block = %{closest_block | z: closest_block.z - Context.MapBlock.block_size()}

    character = maybe_set_safe_position(character, new_position, closest_block)
    character = %{character | animation: state, position: new_position}
    Managers.Character.call(character, {:update, character})

    if out_of_bounds?(character.map_id, character.position) do
      character = handle_out_of_bounds(character)
      fall_distance = Constants.get(:out_of_bounds_fall_distance)
      Managers.Character.cast(character, {:receive_fall_dmg, fall_distance})
      push(session, Packets.MoveCharacter.bytes(character, character.safe_position))
    end
  end

  defp time_condition(@ladder_state), do: :laddertime
  defp time_condition(@rope_state), do: :ropetime
  defp time_condition(@hold_state), do: :holdtime
  defp time_condition(_state), do: nil

  defp track_distance_condition(%{position: nil}, _sync_state), do: :ok

  defp track_distance_condition(character, sync_state) do
    case distance_condition(sync_state.state) do
      nil ->
        :ok

      condition_type ->
        distance =
          Context.MapBlock.subtract(sync_state.position, character.position)
          |> Context.MapBlock.length()

        distances = Map.get(character, :condition_distances, %{})
        total = Map.get(distances, condition_type, 0) + distance
        block_size = Context.MapBlock.block_size()
        progress = trunc(total / block_size)
        distances = Map.put(distances, condition_type, total - progress * block_size)

        Managers.Character.call(
          character,
          {:update, %{character | condition_distances: distances}}
        )

        if progress > 0 do
          Managers.Quest.update_conditions(
            character.id,
            condition_type,
            progress,
            "",
            0,
            "",
            character.map_id
          )
        end
    end
  end

  defp distance_condition(@walk_state), do: :run
  defp distance_condition(@crawl_state), do: :crawl
  defp distance_condition(@fall_state), do: :fall
  defp distance_condition(state) when state in @swim_states, do: :swim
  defp distance_condition(@climb_state), do: :climb
  defp distance_condition(@glide_state), do: :glide
  defp distance_condition(_state), do: nil

  defp maybe_set_safe_position(character, new_position, closest_block) do
    if coord_safe?(character, new_position, closest_block) do
      %{character | safe_position: closest_block}
    else
      character
    end
  end

  defp coord_safe?(character, current_position, closest_block) do
    block_diff = Context.MapBlock.subtract(character.safe_position, closest_block)

    # TODO
    # Maybe not necessary
    # MapBlock.exists?(character.map_id, closest_block)

    Context.MapBlock.length(block_diff) > 350 && character.position.z == current_position.z

    # && !character.on_air_mount?
  end

  defp out_of_bounds?(map_id, coord) do
    %{position1: min, position2: max} = Storage.Maps.get_bounds(map_id)

    {high_z, low_z} = find_high_low_bounds(min.z, max.z)
    {high_y, low_y} = find_high_low_bounds(min.y, max.y)
    {high_x, low_x} = find_high_low_bounds(min.x, max.x)

    coord.z > high_z || coord.z < low_z ||
      coord.y > high_y || coord.y < low_y ||
      coord.x > high_x || coord.x < low_x
  end

  defp find_high_low_bounds(x, y) when x > y, do: {x, y}
  defp find_high_low_bounds(x, y), do: {y, x}

  defp handle_out_of_bounds(%{safe_position: safe_pos} = character) do
    safe_pos = %{safe_pos | z: safe_pos.z + Context.MapBlock.block_size() + 1}

    %{character | safe_position: safe_pos}
  end
end
