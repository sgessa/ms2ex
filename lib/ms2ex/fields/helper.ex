defmodule Ms2ex.FieldHelper do
  require Logger

  alias Ms2ex.{Emotes, Field, Metadata, Packets, World}

  def add_character(character, state) do
    session_pid = character.session_pid
    Process.monitor(session_pid)

    Logger.info("Field #{state.field_id} @ Channel #{state.channel_id}: #{character.name} joined")

    character_ids = Map.keys(state.sessions)

    # Load other characters
    for {_id, char} <- World.get_characters(state.world, character_ids) do
      send(session_pid, {:push, Packets.FieldAddUser.bytes(char)})
      send(session_pid, {:push, Packets.ProxyGameObj.load_player(char)})

      if mount = Map.get(state.mounts, char.id) do
        send(session_pid, {:push, Packets.ResponseRide.start_ride(char, mount)})
      end
    end

    # Load portals
    for {_id, portal} <- state.portals do
      send(session_pid, {:push, Packets.AddPortal.bytes(portal)})
    end

    # Update registry
    character = %{character | object_id: state.counter, map_id: state.field_id}
    World.update_character(state.world, character)

    state = %{state | counter: state.counter + 1}

    # Tell other characters in the map to load the new player
    Field.broadcast(self(), Packets.FieldAddUser.bytes(character))
    Field.broadcast(self(), Packets.ProxyGameObj.load_player(character))

    # Load Emotes and Player Stats after Player Object is loaded
    emotes = Emotes.list(character)
    send(self(), {:push, character.id, Packets.Emote.load(emotes)})
    send(self(), {:push, character.id, Packets.PlayerStats.bytes(character)})

    sessions = Map.put(state.sessions, character.id, session_pid)
    %{state | sessions: sessions}
  end

  def remove_character(character_id, state) do
    mounts = Map.delete(state.mounts, character_id)
    sessions = Map.delete(state.sessions, character_id)

    with {:ok, character} <- World.get_character(state.world, character_id) do
      Logger.info("Field #{state.field_id} @ Channel #{state.channel_id}: #{character.name} left")
      Field.broadcast(self(), Packets.FieldRemoveUser.bytes(character))
    end

    %{state | mounts: mounts, sessions: sessions}
  end

  @object_counter 10
  def initialize_state(world, map_id, channel_id) do
    {:ok, map} = Metadata.Maps.lookup(map_id)

    {counter, portals} =
      Enum.reduce(map.portals, {@object_counter, %{}}, fn portal, {counter, portals} ->
        portal = Map.put(portal, :object_id, counter)
        counter = counter + 1
        {counter, Map.put(portals, portal.id, portal)}
      end)

    %{
      channel_id: channel_id,
      counter: counter,
      field_id: map_id,
      mounts: %{},
      portals: portals,
      sessions: %{},
      world: world
    }
  end
end
