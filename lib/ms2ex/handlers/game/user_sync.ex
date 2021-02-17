defmodule Ms2ex.GameHandlers.UserSync do
  alias Ms2ex.{Damage, Field, Metadata, Packets, SyncState, World}

  import Packets.PacketReader
  import Ms2ex.Net.Session, only: [push: 2]

  def handle(packet, %{character_id: character_id} = session) do
    {_mode, packet} = get_byte(packet)

    {client_tick, packet} = get_int(packet)
    {_server_tick, packet} = get_int(packet)
    {segments, packet} = get_byte(packet)

    with {:ok, character} <- World.get_character(session.world, character_id),
         true <- segments > 0 do
      states = get_states(segments, packet)

      sync_packet = Packets.UserSync.bytes(character, states)
      Field.broadcast(character, sync_packet, session.pid)

      first_state = List.first(states)

      character =
        if is_coord_safe?(character, first_state.position) do
          block = Metadata.Coord.closest_block(character.position)
          %{character | safe_position: block}
        else
          character
        end

      character = %{character | animation: first_state.animation1, position: first_state.position}
      World.update_character(session.world, character)

      session =
        if is_out_of_bounds?(character.map_id, character.position) do
          # TODO this is a temporary solution until we parse the map blocks
          character = handle_out_of_bounds(character)
          character = Damage.receive_fall_dmg(character)
          World.update_character(session.world, character)

          session
          |> push(Packets.UserMoveByPortal.bytes(character))
          |> push(Packets.PlayerStats.bytes(character))
          |> push(Packets.FallDamage.bytes(character, 0))
        else
          session
        end

      %{session | client_tick: client_tick}
    else
      _ ->
        %{session | client_tick: client_tick}
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

  defp is_coord_safe?(character, position) do
    coord = Metadata.Coord.subtract(character.safe_position, position)
    Metadata.Coord.length(coord) > 200 && character.position.z == position.z
    # && !character.on_air_mount?
  end

  defp is_out_of_bounds?(map_id, coord) do
    {:ok, map} = Metadata.Maps.lookup(map_id)
    %{bounding_box_0: box0, bounding_box_1: box1} = map

    z = if box0.z > box1.z, do: box0.z, else: box1.z
    y = if box0.y > box1.y, do: box0.y, else: box1.y
    x = if box0.x > box1.x, do: box0.x, else: box1.x
    higher_bound = %{z: z, y: y, x: x}

    z = if box0.z < box1.z, do: box0.z, else: box1.z
    y = if box0.y < box1.y, do: box0.y, else: box1.y
    x = if box0.x < box1.x, do: box0.x, else: box1.x
    lower_bound = %{z: z, y: y, x: x}

    coord.z > higher_bound.z || coord.z < lower_bound.z ||
      coord.y > higher_bound.y || coord.y < lower_bound.y ||
      coord.x > higher_bound.x || coord.x < lower_bound.x
  end

  defp handle_out_of_bounds(character) do
    safe_position = character.safe_position
    safe_position = %{safe_position | z: safe_position.z + 30}
    %{character | safe_position: safe_position}
  end
end
