defmodule Ms2ex.FieldHelper do
  require Logger

  alias Ms2ex.{
    CharacterManager,
    Emotes,
    Field,
    Inventory,
    Items,
    MapBlock,
    Metadata,
    Mob,
    Packets,
    Wallets
  }

  alias Ms2ex.PremiumMembership, as: Membership
  alias Ms2ex.PremiumMemberships, as: Memberships

  def add_character(character, state) do
    session_pid = character.session_pid

    Logger.info("Field #{state.field_id} @ Channel #{state.channel_id}: #{character.name} joined")

    # Load other characters
    for char_id <- Map.keys(state.sessions) do
      with {:ok, char} <- CharacterManager.lookup(char_id) do
        send(session_pid, {:push, Packets.FieldAddUser.bytes(char)})
        send(session_pid, {:push, Packets.ProxyGameObj.load_player(char)})

        if mount = Map.get(state.mounts, char.id) do
          send(session_pid, {:push, Packets.ResponseRide.start_ride(char, mount)})
        end
      end
    end

    # Update registry
    character = %{character | object_id: state.counter, field_id: state.field_id}
    character = Map.put(character, :field_pid, self())
    CharacterManager.update(character)

    sessions = Map.put(state.sessions, character.id, session_pid)
    state = %{state | counter: state.counter + 1, sessions: sessions}

    # Load Mobs
    mobs = state.mobs |> Map.values() |> List.flatten()

    for obj_id <- mobs do
      with {:ok, mob} <- Mob.lookup(character, obj_id) do
        send(session_pid, {:push, Packets.FieldAddNpc.add_mob(mob)})
        send(session_pid, {:push, Packets.ProxyGameObj.load_npc(mob)})
      end
    end

    # Load NPCs
    for {_id, npc} <- state.npcs do
      send(session_pid, {:push, Packets.FieldAddNpc.add_npc(npc)})
      send(session_pid, {:push, Packets.ProxyGameObj.load_npc(npc)})
    end

    # Load portals
    for {_id, portal} <- state.portals do
      send(session_pid, {:push, Packets.AddPortal.bytes(portal)})
    end

    # Load Interactable Objects
    if map_size(state.interactable) > 0 do
      objects = Map.values(state.interactable)
      send(session_pid, {:push, Packets.AddInteractObjects.bytes(objects)})
    end

    # Tell other characters in the map to load the new player
    Field.broadcast(character, Packets.FieldAddUser.bytes(character))
    Field.broadcast(character, Packets.ProxyGameObj.load_player(character))

    # Load items
    for {_id, item} <- state.items do
      send(session_pid, {:push, Packets.FieldAddItem.add_item(item)})
    end

    for {_id, item} <- state.mob_drops do
      send(session_pid, {:push, Packets.FieldAddItem.add_mob_drop(item)})
    end

    # Load Emotes and Player Stats after Player Object is loaded
    send(session_pid, {:push, Packets.Stats.set_character_stats(character)})

    emotes = Emotes.list(character)
    send(session_pid, {:push, Packets.Emote.load(emotes)})

    # Load Premium membership if active
    with %Membership{} = membership <- Memberships.get(character.account_id),
         false <- Memberships.expired?(membership) do
      send(session_pid, {:push, Packets.PremiumClub.activate(character, membership)})
    end

    # If character teleported or was summoned by an other user
    maybe_teleport_character(character)

    state
  end

  def remove_character(character, state) do
    Logger.info("Field #{state.field_id} @ Channel #{state.channel_id}: #{character.name} left")

    mounts = Map.delete(state.mounts, character.id)
    sessions = Map.delete(state.sessions, character.id)

    Field.broadcast(state.topic, Packets.FieldRemoveObject.bytes(character.object_id))

    %{state | mounts: mounts, sessions: sessions}
  end

  def pickup_item(character, item, state) do
    cond do
      Items.mesos?(item) ->
        :skip

      Items.merets?(item) ->
        Wallets.update(character, :merets, item.amount)

      Items.exp?(item) ->
        # Wallets.update(character, :merets, item.amount)
        :todo

      Items.sp?(item) ->
        CharacterManager.increase_stat(character, :sp, item.amount)

      Items.stamina?(item) ->
        CharacterManager.increase_stat(character, :sta, item.amount)

      true ->
        item = Metadata.Items.load(item)

        with {:ok, result} <- Inventory.add_item(character, item) do
          {_status, item} = result
          send(character.session_pid, {:push, Packets.InventoryItem.add_item(result)})
          send(character.session_pid, {:push, Packets.InventoryItem.mark_item_new(item)})
        end
    end

    Field.broadcast(state.topic, Packets.FieldPickupItem.bytes(character, item))
    Field.broadcast(state.topic, Packets.FieldRemoveItem.bytes(item.object_id))

    items = Map.delete(state.items, item.object_id)
    %{state | items: items}
  end

  def drop_item(character, item, state) do
    item =
      item
      |> Map.put(:position, character.position)
      |> Map.put(:object_id, state.counter)
      |> Map.put(:source_object_id, character.object_id)

    Field.broadcast(state.topic, Packets.FieldAddItem.add_item(item))

    items = Map.put(state.items, state.counter, item)
    %{state | counter: state.counter + 1, items: items}
  end

  def add_mob_drop(mob, item, state) do
    item =
      item
      |> Map.put(:position, mob.position)
      |> Map.put(:object_id, state.counter)
      |> Map.put(:lock_character_id, mob.last_attacker.id)
      |> Map.put(:source_object_id, mob.object_id)
      |> Map.put(:target_object_id, mob.last_attacker.object_id)

    Field.broadcast(state.topic, Packets.FieldAddItem.add_mob_drop(item))

    items = Map.put(state.mob_drops, state.counter, item)
    %{state | counter: state.counter + 1, mob_drops: items}
  end

  def add_mob(%Metadata.Npc{} = npc, position, state) do
    mob = Mob.build(state, npc, position)
    {:ok, _pid} = Mob.start(mob)
    %{state | counter: state.counter + 1}
  end

  def add_mob(%Metadata.MobSpawn{} = spawn_group, %Mob{} = mob, state) do
    case Metadata.Npcs.lookup(mob.id) do
      {:ok, npc} -> add_mob(spawn_group, npc, state)
      _ -> state
    end
  end

  def add_mob(%Metadata.MobSpawn{} = spawn_group, %Metadata.Npc{} = npc, state) do
    population = state.mobs[spawn_group.id] || []
    group_spawn_count = npc.basic.group_spawn_count

    if length(population) + group_spawn_count > spawn_group.data.max_population do
      state
    else
      spawn_points = Metadata.MobSpawn.select_points(spawn_group.spawn_radius)
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
  def initialize_state(field_id, channel_id) do
    {:ok, map} = Metadata.MapEntities.lookup(field_id)

    load_mobs(map)

    {counter, npcs} = load_npcs(map, @object_counter)
    {counter, portals} = load_portals(map, counter)
    {counter, interactable} = load_interactable(map, counter)

    %{
      channel_id: channel_id,
      counter: counter,
      field_id: field_id,
      interactable: interactable,
      items: %{},
      mobs: %{},
      mob_drops: %{},
      mounts: %{},
      npcs: npcs,
      portals: portals,
      sessions: %{},
      topic: "field:#{field_id}:channel:#{channel_id}"
    }
  end

  defp load_npcs(map, counter) do
    map.npcs
    |> Enum.map(&Map.merge(Metadata.Npcs.get(&1.id), &1))
    |> Enum.filter(&(&1.friendly == 2))
    |> Enum.map(&Map.put(&1, :spawn, &1.position))
    |> Enum.reduce({counter, %{}}, fn npc, {counter, npcs} ->
      npc = Map.put(npc, :direction, npc.rotation.z * 10)
      npc = Map.put(npc, :object_id, counter)

      {counter + 1, Map.put(npcs, npc.id, npc)}
    end)
  end

  defp load_mobs(map) do
    map.mob_spawns
    |> Enum.filter(& &1.data)
    |> Enum.each(&spawn_mob_group(&1))
  end

  defp spawn_mob_group(%{data: data} = spawn_group) do
    mobs = Metadata.MobSpawn.select_mobs(data.difficulty, data.min_difficulty, data.tags)
    Enum.each(mobs, &send(self(), {:add_mob, spawn_group, &1}))
  end

  defp load_portals(map, counter) do
    Enum.reduce(map.portals, {counter, %{}}, fn portal, {counter, portals} ->
      portal = Map.put(portal, :object_id, counter)
      {counter + 1, Map.put(portals, portal.id, portal)}
    end)
  end

  defp load_interactable(map, counter) do
    # TODO group these objects by their correct packet type
    Enum.reduce(map.interactable_objects, {counter, %{}}, fn object, {counter, objects} ->
      object = Map.put(object, :object_id, counter)
      {counter + 1, Map.put(objects, object.uuid, object)}
    end)
  end

  defp maybe_teleport_character(%{update_position: coord} = character) do
    character = Map.delete(character, :update_position)
    CharacterManager.update(character)
    send(character.session_pid, {:push, Packets.MoveCharacter.bytes(character, coord)})
  end

  defp maybe_teleport_character(_character), do: nil
end
