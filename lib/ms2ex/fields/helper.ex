defmodule Ms2ex.FieldHelper do
  require Logger

  alias Ms2ex.{
    CharacterManager,
    Emotes,
    Field,
    Metadata,
    Mob,
    Mobs,
    Packets
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
    for {_id, mob} <- state.mobs do
      send(session_pid, {:push, Packets.FieldAddNpc.add_mob(mob)})
      send(session_pid, {:push, Packets.ProxyGameObj.load_npc(mob)})
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
      send(session_pid, {:push, Packets.FieldAddItem.bytes(item)})
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

  def add_item(item, state) do
    item = Map.put(item, :object_id, state.counter)
    items = Map.put(state.items, state.counter, item)

    Field.broadcast(state.topic, Packets.FieldAddItem.bytes(item))

    %{state | counter: state.counter + 1, items: items}
  end

  def add_mob(spawn, state) do
    mob = Mob.build(state.field_id, state.channel_id, state.counter, spawn)
    {:ok, mob_pid} = Mob.start_link(mob)

    mobs = Map.put(state.mobs, state.counter, mob_pid)
    %{state | counter: state.counter + 1, mobs: mobs}
  end

  def remove_mob(mob, state) do
    mobs = Map.delete(state.mobs, mob.object_id)
    Field.broadcast(self(), Packets.FieldRemoveNpc.bytes(mob.object_id))
    %{state | mobs: mobs}
  end

  def respawn_mob(mob, state) do
    add_mob(Mobs.respawn_mob(mob), state)
  end

  # @respawn_intval 10_000
  # def damage_mobs(character, cast, value, coord, object_ids, state) do
  #   targets =
  #     state.mobs
  #     |> Enum.filter(fn {id, _} -> id in object_ids end)
  #     |> Enum.into(%{}, fn {id, target} ->
  #       damage = Damage.calculate(character, target)

  #       target =
  #         case Damage.apply_damage(target, damage) do
  #           {:alive, target} ->
  #             Field.broadcast(state.topic, Packets.Stats.update_health(target))
  #             target

  #           {:dead, target} ->
  #             Field.broadcast(state.topic, Packets.Stats.update_health(target))
  #             Mobs.process_death(character, target)
  #             Process.send_after(self(), {:remove_mob, target}, target.dead_at)

  #             if target.respawn,
  #               do: Process.send_after(self(), {:respawn_mob, target}, @respawn_intval)

  #             target
  #         end

  #       {id, target}
  #     end)

  #   dmg_packet =
  #     Packets.SkillDamage.bytes(character.object_id, cast, value, coord, Map.values(targets))

  #   Field.broadcast(state.topic, dmg_packet)

  #   %{state | mobs: Map.merge(state.mobs, targets)}
  # end

  @object_counter 10_000_001
  def initialize_state(field_id, channel_id) do
    {:ok, map} = Metadata.Maps.lookup(field_id)

    # Load Mobs
    Enum.each(Metadata.MobSpawns.lookup_by_map(map.id), fn spawn ->
      send(self(), {:add_mob, spawn})
    end)

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

  defp load_portals(map, counter) do
    Enum.reduce(map.portals, {counter, %{}}, fn portal, {counter, portals} ->
      portal = Map.put(portal, :object_id, counter)
      {counter + 1, Map.put(portals, portal.id, portal)}
    end)
  end

  defp load_interactable(map, counter) do
    # TODO group these objects by their correct packet type
    Enum.reduce(map.interact_objects, {counter, %{}}, fn object, {counter, objects} ->
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
