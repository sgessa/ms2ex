defmodule Ms2ex.Managers.Field.Character do
  alias Ms2ex.Packets
  alias Ms2ex.Context
  alias Ms2ex.Managers
  alias Ms2ex.Schema

  import Ms2ex.Net.SenderSession, only: [push: 2]
  require Logger

  def add_character(character, state) do
    Logger.info("Field #{state.map_id} @ Channel #{state.channel_id}: #{character.name} joined")

    # Load other characters
    for char_id <- Map.keys(state.sessions) do
      with {:ok, char} <- Managers.Character.lookup(char_id) do
        push(character, Packets.FieldAddUser.bytes(char))
        push(character, Packets.ProxyGameObj.load_player(char))

        if mount = Map.get(state.mounts, char.id) do
          push(character, Packets.ResponseRide.start_ride(char, mount))
        end
      end
    end

    # Update registry
    character = %{character | object_id: state.counter, map_id: state.map_id}
    character = Map.put(character, :field_pid, self())
    Managers.Character.update(character)

    sessions = Map.put(state.sessions, character.id, character.sender_session_pid)
    state = %{state | counter: state.counter + 1, sessions: sessions}

    # Load NPCs
    for {_id, npc} <- state.npcs do
      push(character, Packets.FieldAddNpc.add_npc(npc))
      push(character, Packets.ProxyGameObj.load_npc(npc))
    end

    # Load portals
    for {_id, portal} <- state.portals do
      push(character, Packets.AddPortal.bytes(portal))
    end

    # Load Interactable Objects
    if map_size(state.interactable) > 0 do
      objects = Map.values(state.interactable)
      push(character, Packets.AddInteractObjects.bytes(objects))
    end

    # Tell other characters in the map to load the new player
    Context.Field.broadcast(character, Packets.FieldAddUser.bytes(character))
    Context.Field.broadcast(character, Packets.ProxyGameObj.load_player(character))

    # Load items
    for {_id, item} <- state.items do
      push(character, Packets.FieldAddItem.add_item(item))
    end

    # Load Emotes and Player Stats after Player Object is loaded
    push(character, Packets.Stats.set_character_stats(character))

    emotes = Context.Emotes.list(character)
    push(character, Packets.Emote.load(emotes))

    # Load Premium membership if active
    with %Schema.PremiumMembership{} = membership <-
           Context.PremiumMemberships.get(character.account_id),
         false <- Context.PremiumMemberships.expired?(membership) do
      push(character, Packets.PremiumClub.activate(character, membership))
    end

    # If character teleported or was summoned by an other user
    maybe_teleport_character(character)

    state
  end

  def remove_character(character, state) do
    Logger.info("Field #{state.map_id} @ Channel #{state.channel_id}: #{character.name} left")

    mounts = Map.delete(state.mounts, character.id)
    sessions = Map.delete(state.sessions, character.id)

    Context.Field.broadcast(state.topic, Packets.FieldRemoveObject.bytes(character.object_id))

    %{state | mounts: mounts, sessions: sessions}
  end

  defp maybe_teleport_character(%{update_position: coord} = character) do
    character = Map.delete(character, :update_position)
    Managers.Character.update(character)
    push(character, Packets.MoveCharacter.bytes(character, coord))
  end

  defp maybe_teleport_character(_character), do: nil
end
