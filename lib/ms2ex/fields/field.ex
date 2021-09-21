defmodule Ms2ex.Field do
  alias Ms2ex.{Character, Characters, FieldServer, Metadata, Net, Packets, World}
  alias Phoenix.PubSub

  def add_item(character, item) do
    item = Map.put(item, :position, character.position)
    item = Map.put(item, :character_object_id, character.object_id)
    call(character.field_pid, {:add_item, item})
  end

  def remove_item(character, object_id) do
    call(character.field_pid, {:remove_item, object_id})
  end

  def add_status(character, status) do
    call(character.field_pid, {:add_status, status})
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

  def broadcast(%Character{} = character, packet) do
    topic = field_name(character.map_id, character.channel_id)
    PubSub.broadcast(Ms2ex.PubSub, to_string(topic), {:push, packet})
  end

  def broadcast(topic, packet) when is_binary(topic) do
    PubSub.broadcast(Ms2ex.PubSub, topic, {:push, packet})
  end

  def broadcast_from(%Character{} = character, packet, from) do
    topic = field_name(character.map_id, character.channel_id)
    PubSub.broadcast_from(Ms2ex.PubSub, from, to_string(topic), {:push, packet})
  end

  def subscribe(%Character{} = character) do
    topic = field_name(character.map_id, character.channel_id)
    PubSub.subscribe(Ms2ex.PubSub, to_string(topic))
  end

  def unsubscribe(%Character{} = character) do
    topic = field_name(character.map_id, character.channel_id)
    PubSub.unsubscribe(Ms2ex.PubSub, to_string(topic))
  end

  def enter(%Character{} = character) do
    pid = field_pid(character.map_id, character.channel_id)

    if pid && Process.alive?(pid) do
      call(pid, {:add_character, character})
    else
      GenServer.start(
        FieldServer,
        character,
        name: field_name(character.map_id, character.channel_id)
      )
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
