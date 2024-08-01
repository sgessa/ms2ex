defmodule Ms2ex.FieldHelper do
  require Logger

  alias Ms2ex.{
    CharacterManager,
    Emotes,
    Field,
    Inventory,
    Items,
    MapBlock,
    Storage,
    ProtoMetadata,
    Mob,
    Packets,
    Wallets
  }

  alias Ms2ex.PremiumMembership, as: Membership
  alias Ms2ex.PremiumMemberships, as: Memberships

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

    # Load Mobs
    mobs = state.mobs |> Map.values() |> List.flatten()

    for obj_id <- mobs do
      with {:ok, mob} <- Mob.lookup(character, obj_id) do
        push(character, Packets.FieldAddNpc.add_mob(mob))
        push(character, Packets.ProxyGameObj.load_npc(mob))
      end
    end

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

    emotes = Emotes.list(character)
    push(character, Packets.Emote.load(emotes))

    # Load Premium membership if active
    with %Membership{} = membership <- Memberships.get(character.account_id),
         false <- Memberships.expired?(membership) do
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
      Items.mesos?(item) ->
        Wallets.update(character, :mesos, item.amount)

      Items.valor_token?(item) ->
        Wallets.update(character, :valor_tokens, item.amount)

      Items.merets?(item) ->
        Wallets.update(character, :merets, item.amount)

      Items.rue?(item) ->
        Wallets.update(character, :rues, item.amount)

      Items.havi_fruit?(item) ->
        Wallets.update(character, :havi_fruits, item.amount)

      Items.sp?(item) ->
        CharacterManager.increase_stat(character, :sp, item.amount)

      Items.stamina?(item) ->
        CharacterManager.increase_stat(character, :sta, item.amount)

      true ->
        item = Items.load_metadata(item)

        with {:ok, result} <- Inventory.add_item(character, item) do
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

  def add_mob(%{type: :npc} = npc, position, state) do
    mob = Mob.build(state, npc, position)
    {:ok, _pid} = Mob.start(mob)
    %{state | counter: state.counter + 1}
  end

  def add_mob(%ProtoMetadata.MobSpawn{} = spawn_group, %Mob{} = mob, state) do
    case ProtoMetadata.Npcs.lookup(mob.id) do
      {:ok, npc} -> add_mob(spawn_group, npc, state)
      _ -> state
    end
  end

  def add_mob(%ProtoMetadata.MobSpawn{} = spawn_group, %ProtoMetadata.Npc{} = npc, state) do
    population = state.mobs[spawn_group.id] || []
    group_spawn_count = npc.basic.group_spawn_count

    if length(population) + group_spawn_count > spawn_group.data.max_population do
      state
    else
      spawn_points = ProtoMetadata.MobSpawn.select_points(spawn_group.spawn_radius)
      spawn_point = Enum.at(spawn_points, rem(length(population), length(spawn_points)))
      spawn_position = MapBlock.add(spawn_group.position, spawn_point)

      mob = Mob.build(state, npc, spawn_position, spawn_group)
      {:ok, _pid} = Mob.start(mob)

      population = Map.put(state.mobs, spawn_group.id, [state.counter | population])
      %{state | counter: state.counter + 1, mobs: population}
    end
  end

  def remove_mob(spawn_group_id, object_id, state) do
    population = state.mobs[spawn_group_id] || []
    population = List.delete(population, object_id)
    %{state | mobs: Map.put(state.mobs, spawn_group_id, population)}
  end

  @object_counter 10_000_001
  def initialize_state(map_id, channel_id) do
    # load_mobs(map)

    {counter, npcs} = load_npcs(map_id, @object_counter)
    {counter, portals} = load_portals(map_id, counter)
    # {counter, interactable} = load_interactable(map, counter)

    %{
      channel_id: channel_id,
      counter: counter,
      map_id: map_id,
      interactable: %{},
      items: %{},
      mobs: %{},
      mounts: %{},
      npcs: npcs,
      portals: portals,
      sessions: %{},
      topic: "field:#{map_id}:channel:#{channel_id}"
    }
  end

  defp load_npcs(map_id, counter) do
    map_id
    |> Storage.Maps.get_npcs()
    |> Enum.reduce({counter, %{}}, fn npc, {counter, npcs} ->
      npc =
        npc
        |> Map.put(:current_animation, get_in(npc, [:animation, :id]) || 255)
        |> Map.put(:position, npc.spawn.position)
        |> Map.put(:rotation, npc.spawn.rotation)
        |> Map.put(:direction, trunc(npc.spawn.rotation.z * 10))
        |> Map.put(:object_id, counter)

      {counter + 1, Map.put(npcs, npc.id, npc)}
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

  # defp load_mobs(map) do
  #   map.mob_spawns
  #   |> Enum.filter(& &1.data)
  #   |> Enum.each(&spawn_mob_group(&1))
  # end

  # defp spawn_mob_group(%{data: data} = spawn_group) do
  #   mobs = ProtoMetadata.MobSpawn.select_mobs(data.difficulty, data.min_difficulty, data.tags)
  #   Enum.each(mobs, &send(self(), {:add_mob, spawn_group, &1}))
  # end

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
