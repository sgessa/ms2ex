defmodule Ms2ex.Field do
  alias Ms2ex.{Characters, FieldServer, Metadata, Net, Packets, World}

  def add_item(character, item) do
    item = Map.put(item, :position, character.position)
    item = Map.put(item, :character_object_id, character.object_id)
    call(character.field_pid, {:add_item, item})
  end

  def remove_item(character, object_id) do
    call(character.field_pid, {:remove_item, object_id})
  end

  def add_mob(character, mob) do
    send(character.field_pid, {:add_mob, mob})
  end

  def damage_mobs(character, skill_cast, value, coord, object_ids) do
    call(character.field_pid, {:damage_mobs, character, skill_cast, value, coord, object_ids})
  end

  def add_object(character, object) do
    call(character.field_pid, {:add_object, object.object_type, object})
  end

  def broadcast(character_or_field, packet, sender_pid \\ nil)

  def broadcast(%{field_pid: pid}, packet, sender_pid) do
    if pid, do: send(pid, {:broadcast, packet, sender_pid})
  end

  def broadcast(pid, packet, sender_pid) when is_pid(pid) do
    send(pid, {:broadcast, packet, sender_pid})
  end

  def enter(%{map_id: field_id} = character, %{channel_id: channel_id} = session) do
    pid = field_pid(field_id, channel_id)

    if pid && Process.alive?(pid) do
      call(pid, {:add_character, character})
    else
      GenServer.start(FieldServer, {character, session}, name: field_name(field_id, channel_id))
    end
  end

  def change_field(character, session, field_id) do
    with {:ok, map} <- Metadata.Maps.lookup(field_id) do
      spawn = List.first(map.spawns)
      change_field(character, session, field_id, spawn.coord, spawn.rotation)
    else
      _ -> session
    end
  end

  def change_field(character, session, field_id, coord, rotation) do
    with :ok <- leave(character) do
      character =
        character
        |> Characters.maybe_discover_map(field_id)
        |> Map.put(:change_map, %{id: field_id, position: coord, rotation: rotation})

      World.update_character(character)

      Net.Session.push(session, Packets.RequestFieldEnter.bytes(field_id, coord, rotation))
    else
      _ -> session
    end
  end

  def leave(character) do
    call(character.field_pid, {:remove_character, character})
  end

  def push(session_pid, packet), do: send(session_pid, {:push, packet})

  defp field_pid(field_id, channel_id) do
    Process.whereis(field_name(field_id, channel_id))
  end

  defp field_name(field_id, channel_id) do
    :"field:#{field_id}:channel:#{channel_id}"
  end

  defp call(nil, _args), do: :error
  defp call(pid, args), do: GenServer.call(pid, args)
end
