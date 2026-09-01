defmodule Ms2ex.Managers.Field do
  use GenServer

  require Logger

  alias Ms2ex.Context
  alias Ms2ex.Packets
  alias Ms2ex.Schema

  alias Ms2ex.Types.FieldNpc
  alias Ms2ex.Types.Npc

  alias Ms2ex.Managers.Field

  @updates_intval 1000

  @npc_tick_intval 15

  # one app-wide counter feeds players and mounts, while each field instance
  # owns a local counter for npcs, portals, spawn points and items
  @local_id_counter 50_000_000

  def next_local_id(state) do
    id = state.local_id_counter + 1
    {id, %{state | local_id_counter: id}}
  end

  def init(%{map_id: map_id, channel_id: channel_id} = character) do
    Logger.info("Start Field #{map_id} @ Channel #{channel_id}")

    field_name = Context.Field.field_name(map_id, channel_id)

    {local_id_counter, portals} = Field.Portal.load(map_id, @local_id_counter)
    # {counter, interactable} = load_interactable(map, counter)

    state = %{
      buffs: %{},
      channel_id: channel_id,
      local_id_counter: local_id_counter,
      interactable: %{},
      items: %{},
      map_id: map_id,
      mounts: %{},
      npcs: %{},
      npc_spawns: %{},
      players: %{},
      portals: portals,
      regions: %{},
      sessions: %{},
      tombstones: %{},
      topic: field_name
    }

    send(self(), :load_npc_spawns)
    send(self(), :tick_npcs)

    {:ok, state, {:continue, {:add_character, character}}}
  end

  # defp load_interactable(map, counter) do
  #   # TODO group these objects by their correct packet type
  #   Enum.reduce(map.interactable_objects, {counter, %{}}, fn object, {counter, objects} ->
  #     object = Map.put(object, :object_id, counter)
  #     {counter + 1, Map.put(objects, object.uuid, object)}
  #   end)
  # end

  def handle_continue({:add_character, character}, state),
    do: {:noreply, Field.Character.add_character(character, state)}

  def handle_call({:add_character, character}, _from, state),
    do: {:reply, {:ok, self()}, Field.Character.add_character(character, state)}

  def handle_call({:remove_character, character}, _from, state) do
    send(self(), :maybe_stop)

    {:reply, :ok, Field.Character.remove_character(character, state)}
  end

  def handle_call({:pickup_item, character, object_id}, _from, state) do
    case Map.get(state.items, object_id) do
      nil ->
        {:reply, :error, state}

      item ->
        {:reply, {:ok, item}, Field.Item.pickup_item(character, item, state)}
    end
  end

  def handle_call({:hit_tombstone, object_id, hits}, _from, state) do
    case Field.Tombstone.hit(object_id, hits, state) do
      {:ok, state} ->
        {:reply, :ok, state}

      {:error, state} ->
        {:reply, :error, state}
    end
  end

  def handle_call({:add_region_skill, skill_cast}, _from, state),
    do: {:reply, :ok, Field.RegionSkill.add(skill_cast, state)}

  def handle_call({:add_buff, skill_cast, skill, character}, _from, state) do
    case Field.Buff.add_buff(skill_cast, skill, character, state) do
      {nil, state} ->
        {:reply, :error, state}

      {buff, state} ->
        {:reply, {:ok, buff}, state}
    end
  end

  def handle_call({:add_effect_buff, effect_id, effect_level, character}, _from, state) do
    {_buff, state} = Field.Buff.add_effect_buff(effect_id, effect_level, character, state)
    {:reply, :ok, state}
  end

  def handle_call({:lookup_npc, object_id}, _from, state) do
    case Map.get(state.npcs, object_id) do
      nil -> {:reply, :error, state}
      npc -> {:reply, {:ok, npc}, state}
    end
  end

  def handle_call({:inflict_dmg, attacker, %{dmg: dmg}, object_id}, _from, state) do
    case Field.Npc.damage(state, attacker, dmg, object_id) do
      {:ok, field_npc, state} ->
        {:reply, {:ok, field_npc}, state}

      {:error, state} ->
        {:reply, :error, state}
    end
  end

  def handle_call({:apply_skill_effects, skill_cast, mob_id}, _from, state),
    do: {:reply, :ok, Field.Npc.apply_skill_effects(state, skill_cast, mob_id)}

  def handle_cast({:drop_item, source, item}, state),
    do: {:noreply, Field.Item.drop_item(source, item, state)}

  def handle_cast({:add_mob_drop, %FieldNpc{} = mob, %Schema.Item{} = item, receiver}, state),
    do: {:noreply, Field.Item.add_mob_drop(mob, item, receiver, state)}

  # a dead player's tombstone is broadcast so other players can hit it; the
  # owner is keyed by character id for the revive lookup
  def handle_cast({:add_tombstone, character}, state),
    do: {:noreply, Field.Tombstone.add(character, state)}

  def handle_cast({:remove_tombstone, character_id}, state),
    do: {:noreply, Field.Tombstone.remove(character_id, state)}

  # buffs die with their owner; remove every buff owned by the object id
  def handle_cast({:remove_owner_buffs, owner_object_id}, state),
    do: {:noreply, Field.Buff.remove_owner_buffs(owner_object_id, state)}

  def handle_cast({:enter_battle_stance, character}, state) do
    # battle-start packets are emitted by the cast handler in order; the
    # field process only schedules the eventual stance drop
    Process.send_after(self(), {:leave_battle_stance, character}, 5_000)
    {:noreply, state}
  end

  #
  # NPCs
  #

  def handle_info(:load_npc_spawns, state) do
    Field.Npc.load_npc_spawns(state)
    Field.Npc.load_mob_spawns(state)
    {:noreply, state}
  end

  def handle_info({:add_npc_spawn, npc_spawn, npc_ids}, state),
    do: {:noreply, Field.Npc.load_spawn(state, npc_spawn, npc_ids)}

  def handle_info({:add_npc, npc_id, npc_spawn}, state),
    do: {:noreply, Field.Npc.load_npc(state, npc_id, npc_spawn)}

  def handle_info({:add_mob, %Npc{} = npc, position}, state),
    do: {:noreply, Field.Npc.load_npc(state, npc, %{position: position, rotation: nil})}

  def handle_info({:remove_npc, field_npc}, state) do
    Context.Field.broadcast(field_npc.field, Packets.FieldRemoveNpc.bytes(field_npc.object_id))
    Context.Field.broadcast(field_npc.field, Packets.ProxyGameObj.remove_npc(field_npc))

    {:noreply, Field.Npc.remove_npc(field_npc, state)}
  end

  def handle_info(:tick_npcs, state) do
    Process.send_after(self(), :tick_npcs, @npc_tick_intval)
    {:noreply, Field.Npc.tick(state)}
  end

  def handle_info({:region_tick, source_id}, state),
    do: {:noreply, Field.RegionSkill.maybe_tick(source_id, state)}

  def handle_info({:remove_region_skill, source_id}, state) do
    Context.Field.broadcast(state.topic, Packets.RegionSkill.remove(source_id))
    {:noreply, state}
  end

  def handle_info({:remove_status, status}, state) do
    Context.Field.broadcast(state.topic, Packets.Buff.send(:remove, status))
    {:noreply, state}
  end

  def handle_info({:buff_tick, buff_id}, state) do
    state = Field.Buff.tick(buff_id, state)
    {:noreply, state}
  end

  def handle_info({:remove_buff, buff_id}, state) do
    state = Field.Buff.remove_buff(buff_id, state)
    {:noreply, state}
  end

  def handle_info({:leave_battle_stance, character}, state) do
    Field.Character.leave_battle_stance(character)
    {:noreply, state}
  end

  def handle_info(:send_updates, state) do
    Process.send_after(self(), :send_updates, @updates_intval)
    {:noreply, Field.Character.send_updates(state)}
  end

  def handle_info(:maybe_stop, state) do
    if Enum.empty?(state.sessions) do
      Logger.info("Field #{state.map_id} @ Channel #{state.channel_id} is empty. Stopping.")
      {:stop, :normal, state}
    else
      {:noreply, state}
    end
  end

  def handle_info(data, state) do
    Logger.warning("[Field] Unknown message: #{inspect(data)}")
    {:noreply, state}
  end
end
