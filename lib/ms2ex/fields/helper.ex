defmodule Ms2ex.FieldHelper do
  require Logger

  alias Ms2ex.{
    CharacterManager,
    Context,
    Field,
    Packets,
    Schema,
    Storage,
    Types
  }

  import Ms2ex.Net.SenderSession, only: [push: 2]

  def add_character(character, state) do
    Logger.info("Field #{state.map_id} @ Channel #{state.channel_id}: #{character.name} joined")

    # Load other characters
    for char_id <- Map.keys(state.sessions) do
      with {:ok, char} <- CharacterManager.lookup(char_id) do
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
    CharacterManager.update(character)

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
    Field.broadcast(character, Packets.FieldAddUser.bytes(character))
    Field.broadcast(character, Packets.ProxyGameObj.load_player(character))

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

    Field.broadcast(state.topic, Packets.FieldRemoveObject.bytes(character.object_id))

    %{state | mounts: mounts, sessions: sessions}
  end

  def pickup_item(character, item, state) do
    cond do
      Context.Items.mesos?(item) ->
        Context.Wallets.update(character, :mesos, item.amount)

      Context.Items.valor_token?(item) ->
        Context.Wallets.update(character, :valor_tokens, item.amount)

      Context.Items.merets?(item) ->
        Context.Wallets.update(character, :merets, item.amount)

      Context.Items.rue?(item) ->
        Context.Wallets.update(character, :rues, item.amount)

      Context.Items.havi_fruit?(item) ->
        Context.Wallets.update(character, :havi_fruits, item.amount)

      Context.Items.sp?(item) ->
        CharacterManager.increase_stat(character, :sp, item.amount)

      Context.Items.stamina?(item) ->
        CharacterManager.increase_stat(character, :sta, item.amount)

      true ->
        item = Context.Items.load_metadata(item)

        with {:ok, result} <- Context.Inventory.add_item(character, item) do
          {_status, item} = result
          push(character, Packets.InventoryItem.add_item(result))
          push(character, Packets.InventoryItem.mark_item_new(item))
        end
    end

    Field.broadcast(state.topic, Packets.FieldPickupItem.bytes(character, item))
    Field.broadcast(state.topic, Packets.FieldRemoveItem.bytes(item.object_id))

    items = Map.delete(state.items, item.object_id)
    %{state | items: items}
  end

  def drop_item(character, item, state) do
    item = %{
      item
      | position: character.position,
        object_id: state.counter,
        source_object_id: character.object_id
    }

    Field.broadcast(state.topic, Packets.FieldAddItem.add_item(item))

    items = Map.put(state.items, state.counter, item)
    %{state | counter: state.counter + 1, items: items}
  end

  def add_mob_drop(mob, item, state) do
    item = %{
      item
      | position: mob.position,
        object_id: state.counter,
        lock_character_id: mob.last_attacker.id,
        mob_drop?: true,
        source_object_id: mob.object_id,
        target_object_id: mob.last_attacker.object_id
    }

    Field.broadcast(state.topic, Packets.FieldAddItem.add_item(item))

    items = Map.put(state.items, state.counter, item)
    %{state | counter: state.counter + 1, items: items}
  end

  @object_counter 10_000_000
  def initialize_state(map_id, channel_id) do
    {counter, npc_spawns, npcs, mobs} = load_npcs(map_id, @object_counter)
    {counter, portals} = load_portals(map_id, counter)
    # {counter, interactable} = load_interactable(map, counter)

    %{
      channel_id: channel_id,
      counter: counter,
      interactable: %{},
      items: %{},
      map_id: map_id,
      mobs: mobs,
      mounts: %{},
      npcs: npcs,
      npc_spawns: npc_spawns,
      portals: portals,
      sessions: %{},
      topic: "field:#{map_id}:channel:#{channel_id}"
    }
  end

  defp load_npcs(map_id, counter) do
    map_id
    |> Storage.Maps.get_npcs()
    |> Enum.reduce({counter, %{}, %{}, %{}}, fn npc, {counter, npc_spawns, npcs, mobs} ->
      regen_check_time = get_in(npc, [:spawn, :regen_check_time])

      {counter, npc_spawns} =
        if regen_check_time && regen_check_time > 0 do
          counter = counter + 1
          {counter, Map.put(npc_spawns, counter, npc.spawn)}
        else
          {counter, npc_spawns}
        end

      spawn_point_id = counter
      counter = counter + 1

      field_npc =
        %Types.FieldNpc{}
        |> Map.put(:spawn_point_id, spawn_point_id)
        |> Map.put(:npc, Types.Npc.new(%{id: npc.id, metadata: npc.metadata}))
        |> Map.put(:animation, get_in(npc, [:animation, :id]) || 255)
        |> Map.put(:position, struct(Types.Coord, npc.spawn.position))
        |> Map.put(:rotation, struct(Types.Coord, npc.spawn.rotation))
        |> Map.put(:object_id, counter)

      friendly = get_in(npc, [:metadata, :basic, :friendly]) || 0

      if friendly > 0 do
        {counter + 1, npc_spawns, Map.put(npcs, field_npc.object_id, field_npc), mobs}
      else
        {counter + 1, npc_spawns, npcs, Map.put(mobs, field_npc.object_id, npc)}
      end
    end)
  end

  defp load_portals(map_id, counter) do
    map_id
    |> Storage.Maps.get_portals()
    |> Enum.reduce({counter, %{}}, fn portal, {counter, portals} ->
      portal = Map.put(portal, :object_id, counter)
      {counter + 1, Map.put(portals, portal.id, portal)}
    end)
  end

  # defp load_interactable(map, counter) do
  #   # TODO group these objects by their correct packet type
  #   Enum.reduce(map.interactable_objects, {counter, %{}}, fn object, {counter, objects} ->
  #     object = Map.put(object, :object_id, counter)
  #     {counter + 1, Map.put(objects, object.uuid, object)}
  #   end)
  # end

  defp maybe_teleport_character(%{update_position: coord} = character) do
    character = Map.delete(character, :update_position)
    CharacterManager.update(character)
    push(character, Packets.MoveCharacter.bytes(character, coord))
  end

  defp maybe_teleport_character(_character), do: nil
end
