defmodule Ms2ex.GameHandlers.UserSync do
  alias Ms2ex.{CharacterManager, Context, Field, Storage, Packets, SyncState}

  import Packets.PacketReader
  import Ms2ex.Net.SenderSession, only: [push: 2]

  def handle(packet, session) do
    {_mode, packet} = get_byte(packet)

    {client_tick, packet} = get_int(packet)
    {_server_tick, packet} = get_int(packet)
    {segment_length, packet} = get_byte(packet)

    send(self(), {:update, %{client_tick: client_tick}})

    process_segments(session, segment_length, packet)
  end

  defp process_segments(session, segment_length, packet) when segment_length > 0 do
    {:ok, character} = CharacterManager.lookup(session.character_id)

    states = get_states(segment_length, packet)

    sync_packet = Packets.UserSync.bytes(character, states)
    Field.broadcast_from(character, sync_packet, session.sender_pid)

    %{animation1: animation, position: new_position} = List.first(states)
    closest_block = Context.MapBlock.closest_block(new_position)
    # Get the block under the character
    closest_block = %{closest_block | z: closest_block.z - Context.MapBlock.block_size()}

    character = maybe_set_safe_position(character, new_position, closest_block)
    character = %{character | animation: animation, position: new_position}
    CharacterManager.update(character)

    if is_out_of_bounds?(character.map_id, character.position) do
      character = handle_out_of_bounds(character)
      CharacterManager.receive_fall_dmg(character)
      push(session, Packets.MoveCharacter.bytes(character, character.safe_position))
    end
  end

  defp get_states(segments, packet, state \\ [])

  defp get_states(segments, packet, states) when segments > 0 do
    {sync_state, packet} = SyncState.from_packet(packet)
    {_client_tick, packet} = get_int(packet)
    {_server_tick, packet} = get_int(packet)
    get_states(segments - 1, packet, states ++ [sync_state])
  end

  defp get_states(_segments, _packet, states), do: states

  defp maybe_set_safe_position(character, new_position, closest_block) do
    if is_coord_safe?(character, new_position, closest_block) do
      %{character | safe_position: closest_block}
    else
      character
    end
  end

  defp is_coord_safe?(character, current_position, closest_block) do
    block_diff = Context.MapBlock.subtract(character.safe_position, closest_block)

    # TODO
    # Maybe not necessary
    # MapBlock.exists?(character.map_id, closest_block)

    Context.MapBlock.length(block_diff) > 350 && character.position.z == current_position.z

    # && !character.on_air_mount?
  end

  defp is_out_of_bounds?(map_id, coord) do
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

  defp handle_out_of_bounds(%{position: pos, safe_position: safe_pos} = character) do
    # Without this player will spawn inside the block
    # for some reason if coord is negative player is teleported one block over,
    # which can result player being stuck inside a block
    safe_pos = %{safe_pos | z: safe_pos.z + Context.MapBlock.block_size() + 1}

    safe_pos =
      if pos.x < 0 do
        %{safe_pos | x: safe_pos.x - Context.MapBlock.block_size()}
      else
        safe_pos
      end

    safe_pos =
      if pos.y < 0 do
        %{safe_pos | y: safe_pos.y - Context.MapBlock.block_size()}
      else
        safe_pos
      end

    %{character | safe_position: safe_pos}
  end
end
