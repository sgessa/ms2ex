defmodule Ms2ex.FieldHelper do
  require Logger

  alias Ms2ex.{Damage, Emotes, Field, Metadata, Mobs, Packets, World}

  def add_character(character, state) do
    session_pid = character.session_pid

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

    # Update registry
    character = %{character | object_id: state.counter, map_id: state.field_id}
    character = Map.put(character, :field_pid, self())
    World.update_character(state.world, character)

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

    # Tell other characters in the map to load the new player
    broadcast(state.sessions, Packets.FieldAddUser.bytes(character))
    broadcast(state.sessions, Packets.ProxyGameObj.load_player(character))

    # Load items
    for {_id, item} <- state.items do
      send(session_pid, {:push, Packets.FieldAddItem.bytes(item)})
    end

    # Load Emotes and Player Stats after Player Object is loaded
    emotes = Emotes.list(character)
    send(session_pid, {:push, Packets.Emote.load(emotes)})
    send(session_pid, {:push, Packets.Stats.set_character_stats(character)})

    # If character teleported or was summoned by an other user
    maybe_teleport_character(state.world, character)

    state
  end

  def remove_character(character, state) do
    Logger.info("Field #{state.field_id} @ Channel #{state.channel_id}: #{character.name} left")

    mounts = Map.delete(state.mounts, character.id)
    sessions = Map.delete(state.sessions, character.id)

    Field.broadcast(self(), Packets.FieldRemoveObject.bytes(character.object_id))

    %{state | mounts: mounts, sessions: sessions}
  end

  def add_item(item, state) do
    item = Map.put(item, :object_id, state.counter)
    items = Map.put(state.items, state.counter, item)

    broadcast(state.sessions, Packets.FieldAddItem.bytes(item))

    %{state | counter: state.counter + 1, items: items}
  end

  def add_mob(mob, state) do
    mob = Mobs.init_mob(mob, state.counter)
    mobs = Map.put(state.mobs, state.counter, mob)

    broadcast(state.sessions, Packets.FieldAddNpc.add_mob(mob))
    broadcast(state.sessions, Packets.ProxyGameObj.load_npc(mob))

    %{state | counter: state.counter + 1, mobs: mobs}
  end

  def remove_mob(mob, state) do
    mobs = Map.delete(state.mobs, mob.object_id)
    Field.broadcast(self(), Packets.FieldRemoveObject.bytes(mob.object_id))
    %{state | mobs: mobs}
  end

  def respawn_mob(mob, state) do
    add_mob(Mobs.respawn_mob(mob), state)
  end

  @respawn_intval 10_000
  def damage_mobs(character, cast, value, coord, object_ids, state) do
    targets =
      state.mobs
      |> Enum.filter(fn {id, _} -> id in object_ids end)
      |> Enum.into(%{}, fn {id, target} ->
        damage = Damage.calculate(character, target)

        target =
          case Damage.apply_damage(target, damage) do
            {:alive, target} ->
              broadcast(state.sessions, Packets.Stats.update_health(target))
              target

            {:dead, target} ->
              broadcast(state.sessions, Packets.Stats.update_health(target))
              Mobs.process_death(state.world, character, target)
              Process.send_after(self(), {:remove_mob, target}, remove_mob_intval(target))

              if target.respawn,
                do: Process.send_after(self(), {:respawn_mob, target}, @respawn_intval)

              target
          end

        {id, target}
      end)

    dmg_packet =
      Packets.SkillDamage.bytes(character.object_id, cast, value, coord, Map.values(targets))

    broadcast(state.sessions, dmg_packet)

    %{state | mobs: Map.merge(state.mobs, targets)}
  end

  # TODO read time from metadata
  defp remove_mob_intval(%{boss?: true}), do: 7_000
  defp remove_mob_intval(_mob), do: 3_000

  @object_counter 10_000_001
  def initialize_state(world, map_id, channel_id) do
    {:ok, map} = Metadata.Maps.lookup(map_id)

    {counter, npcs} = load_npcs(map, @object_counter)
    {counter, portals} = load_portals(map, counter)

    load_mobs(map)

    %{
      channel_id: channel_id,
      counter: counter,
      field_id: map_id,
      items: %{},
      mobs: %{},
      mounts: %{},
      npcs: npcs,
      portals: portals,
      sessions: %{},
      world: world
    }
  end

  defp load_mobs(map) do
    map.npcs
    |> Enum.map(&Map.delete(&1, :__struct__))
    |> Enum.map(&Map.merge(Metadata.Npcs.get(&1.id), &1))
    |> Enum.map(&Map.put(&1, :spawn, &1.position))
    |> Enum.filter(&(&1.friendly != 2))
    |> Enum.each(&send(self(), {:add_mob, &1}))
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

  def broadcast(sessions, packet, sender_pid \\ nil) do
    for {_char_id, pid} <- sessions, pid != sender_pid do
      send(pid, {:push, packet})
    end
  end

  defp maybe_teleport_character(world, %{update_position: coord} = character) do
    character = Map.delete(character, :update_position)
    World.update_character(world, character)
    send(character.session_pid, {:push, Packets.MoveCharacter.bytes(character, coord)})
  end

  defp maybe_teleport_character(session, _character), do: session
end
