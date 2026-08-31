defmodule Ms2ex.Managers.Field.Character do
  alias Ms2ex.Packets
  alias Ms2ex.Context
  alias Ms2ex.Managers
  alias Ms2ex.Schema

  import Ms2ex.Net.SenderSession, only: [push: 2]
  require Logger

  def add_character(character, state) do
    Logger.info("Field #{state.map_id} @ Channel #{state.channel_id}: #{character.name} joined")
    # Capture before field_pid is set so we can distinguish first login from map changes.
    initial_login? = is_nil(character.field_pid)

    character = Context.ItemStats.apply(character)

    # Load other characters
    for char_id <- Map.keys(state.sessions) do
      load_peer(character, char_id, state)
    end

    # Update registry; players and mounts share the app-wide counter
    character = %{
      character
      | object_id: Managers.GlobalCounter.get_and_increment(),
        map_id: state.map_id
    }

    character = Map.put(character, :field_pid, self())
    Managers.Character.update(character)

    sessions = Map.put(state.sessions, character.id, character.sender_session_pid)
    players = Map.put(state.players, character.id, character.object_id)
    state = %{state | sessions: sessions, players: players}

    # field-object systems must be initialized before entities load
    push(character, Packets.LoadCubes.load_plots())
    push(character, Packets.LoadCubes.load())
    push(character, Packets.LoadCubes.plot_state())
    push(character, Packets.LoadCubes.plot_expiry())
    push(character, Packets.Ugc.load())
    push(character, Packets.Breakable.load())
    push(character, Packets.Liftable.load())
    push(character, Packets.AddInteractObjects.bytes([]))
    push(character, Packets.FunctionCube.load())

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

    # trigger/ui state finalizes before the player stats load
    push(character, Packets.Trigger.load())
    push(character, Packets.FieldProperty.load())

    # Load Emotes and Player Stats after Player Object is loaded
    push(character, Packets.Stats.set_character_stats(character))

    push(character, Packets.UserState.bytes(character))

    emotes = Context.Emotes.list(character)
    push(character, Packets.Emote.load(emotes))

    push(character, Packets.SkillMacro.load())
    push(character, Packets.Wedding.update_marriage())
    push(character, Packets.Wedding.update_hall())
    push(character, Packets.ResponseCube.design_rank_reward(character.account_id))
    push(character, Packets.ResponseCube.update_profile(character))
    push(character, Packets.ResponseCube.return_map(character.map_id))
    push(character, Packets.Lapenshard.load())

    tick = Ms2ex.sync_ticks()
    push(character, Packets.RevivalCount.bytes())
    push(character, Packets.RevivalConfirm.bytes(character.object_id, tick))

    if initial_login? do
      total = character.stat_point_sources |> Map.values() |> Enum.sum()
      push(character, Packets.StatPoints.sources(character.stat_point_sources))
      push(character, Packets.StatPoints.allocation(character.stat_point_allocation, total))
    end

    push(character, Packets.SkillPoint.sources())

    # Load Premium membership if active
    with %Schema.PremiumMembership{} = membership <-
           Context.PremiumMemberships.get(character.account_id),
         false <- Context.PremiumMemberships.expired?(membership) do
      push(character, Packets.PremiumClub.activate(character, membership))
    end

    push(character, Packets.DynamicChannel.bytes())

    # If character teleported or was summoned by an other user
    maybe_teleport_character(character)

    state
  end

  # loads a peer character (and any mount they are riding) for the joining player
  defp load_peer(character, char_id, state) do
    with {:ok, char} <- Managers.Character.lookup(char_id) do
      push(character, Packets.FieldAddUser.bytes(char))
      push(character, Packets.ProxyGameObj.load_player(char))

      if mount = Map.get(state.mounts, char.id) do
        push(character, Packets.ResponseRide.start_ride(char, mount))
      end
    end
  end

  def remove_character(character, state) do
    Logger.info("Field #{state.map_id} @ Channel #{state.channel_id}: #{character.name} left")

    mounts = Map.delete(state.mounts, character.id)
    sessions = Map.delete(state.sessions, character.id)
    players = Map.delete(state.players, character.id)

    Context.Field.broadcast(state.topic, Packets.FieldRemoveObject.bytes(character.object_id))
    Context.Field.broadcast(state.topic, Packets.ProxyGameObj.remove_player(character.object_id))

    %{state | mounts: mounts, sessions: sessions, players: players}
  end

  defp maybe_teleport_character(character) do
    case Map.get(character, :update_position) do
      nil ->
        :ok

      coord ->
        character = %{character | update_position: nil}
        Managers.Character.update(character)
        push(character, Packets.MoveCharacter.bytes(character, coord))
    end
  end
end
