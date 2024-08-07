defmodule Ms2ex.Managers.Field do
  use GenServer

  require Logger

  alias Ms2ex.{
    Managers,
    Context,
    Packets,
    Schema
  }

  alias Ms2ex.Types.FieldNpc
  alias Ms2ex.Managers.Field

  @updates_intval 1000

  @object_counter 10_000_000
  def init(%{map_id: map_id, channel_id: channel_id} = character) do
    Logger.info("Start Field #{map_id} @ Channel #{channel_id}")

    field_name = Context.Field.field_name(map_id, channel_id)

    {counter, portals} = Field.Portal.load(map_id, @object_counter)
    # {counter, interactable} = load_interactable(map, counter)

    state = %{
      channel_id: channel_id,
      counter: counter,
      interactable: %{},
      items: %{},
      map_id: map_id,
      mounts: %{},
      npcs: %{},
      npc_spawns: %{},
      portals: portals,
      sessions: %{},
      topic: field_name
    }

    send(self(), :load_npc_spawns)
    send(self(), :send_updates)

    {:ok, state, {:continue, {:add_character, character}}}
  end

  # defp load_interactable(map, counter) do
  #   # TODO group these objects by their correct packet type
  #   Enum.reduce(map.interactable_objects, {counter, %{}}, fn object, {counter, objects} ->
  #     object = Map.put(object, :object_id, counter)
  #     {counter + 1, Map.put(objects, object.uuid, object)}
  #   end)
  # end

  def handle_continue({:add_character, character}, state) do
    {:noreply, Field.Character.add_character(character, state)}
  end

  def handle_call({:add_character, character}, _from, state) do
    {:reply, {:ok, self()}, Field.Character.add_character(character, state)}
  end

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

  def handle_call({:add_region_skill, position, skill}, _from, state) do
    source_id = Ms2ex.generate_int()

    Context.Field.broadcast(
      state.topic,
      Packets.RegionSkill.add(source_id, position, skill)
    )

    duration = Managers.SkillCast.duration(skill)
    Process.send_after(self(), {:remove_region_skill, source_id}, duration + 5000)
    {:reply, :ok, state}
  end

  def handle_call({:add_status, status}, _from, state) do
    Context.Field.broadcast(state.topic, Packets.Buff.send(:add, status))
    Process.send_after(self(), {:remove_status, status}, status.duration)
    {:reply, :ok, state}
  end

  def handle_call({:add_object, :mount, mount}, _from, state) do
    mount = Map.put(mount, :object_id, state.counter)
    mounts = Map.put(state.mounts, mount.character_id, mount)
    {:reply, {:ok, mount}, %{state | counter: state.counter + 1, mounts: mounts}}
  end

  def handle_cast({:drop_item, source, item}, state) do
    {:noreply, Field.Item.drop_item(source, item, state)}
  end

  def handle_cast({:add_mob_drop, %FieldNpc{} = mob, %Schema.Item{} = item}, state) do
    {:noreply, Field.Item.add_mob_drop(mob, item, state)}
  end

  def handle_cast({:enter_battle_stance, character}, state) do
    Context.Field.broadcast(character, Packets.UserBattle.set_stance(character, true))
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

  def handle_info({:add_npc_spawn, npc_spawn, npc_ids}, state) do
    {:noreply, Field.Npc.load_spawn(state, npc_spawn, npc_ids)}
  end

  def handle_info({:add_npc, npc_id, npc_spawn}, state) do
    {:noreply, Field.Npc.load_npc(state, npc_id, npc_spawn)}
  end

  def handle_info({:remove_npc, field_npc}, state) do
    Context.Field.broadcast(field_npc.field, Packets.FieldRemoveNpc.bytes(field_npc.object_id))
    Context.Field.broadcast(field_npc.field, Packets.ProxyGameObj.remove_npc(field_npc))

    {:noreply, Field.Npc.remove_npc(field_npc, state)}
  end

  def handle_info({:remove_region_skill, source_id}, state) do
    Context.Field.broadcast(state.topic, Packets.RegionSkill.remove(source_id))
    {:noreply, state}
  end

  def handle_info({:remove_status, status}, state) do
    Context.Field.broadcast(state.topic, Packets.Buff.send(:remove, status))
    {:noreply, state}
  end

  def handle_info({:leave_battle_stance, character}, state) do
    Context.Field.broadcast(character, Packets.UserBattle.set_stance(character, false))
    {:noreply, state}
  end

  def handle_info(:send_updates, state) do
    for char_id <- Map.keys(state.sessions) do
      with {:ok, char} <- Managers.Character.lookup(char_id) do
        Context.Field.broadcast(state.topic, Packets.ProxyGameObj.update_player(char))
      end
    end

    Process.send_after(self(), :send_updates, @updates_intval)

    {:noreply, state}
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
