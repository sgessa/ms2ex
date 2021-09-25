defmodule Ms2ex.FieldServer do
  use GenServer

  require Logger

  alias Ms2ex.{CharacterManager, Field, FieldHelper, Packets, SkillCast}

  import FieldHelper

  @updates_intval 1000

  def init(character) do
    Logger.info("Start Field #{character.field_id} @ Channel #{character.channel_id}")

    send(self(), :send_updates)

    {
      :ok,
      initialize_state(character.field_id, character.channel_id),
      {:continue, {:add_character, character}}
    }
  end

  def handle_continue({:add_character, character}, state) do
    {:noreply, add_character(character, state)}
  end

  def handle_call({:add_character, character}, _from, state) do
    {:reply, {:ok, self()}, add_character(character, state)}
  end

  def handle_call({:remove_character, character}, _from, state) do
    send(self(), :maybe_stop)
    {:reply, :ok, remove_character(character, state)}
  end

  def handle_call({:add_item, item}, _from, state) do
    {:reply, {:ok, item}, add_item(item, state)}
  end

  def handle_call({:remove_item, object_id}, _from, state) do
    case Map.get(state.items, object_id) do
      nil ->
        {:reply, :error, state}

      item ->
        items = Map.delete(state.items, object_id)
        Field.broadcast(state.topic, Packets.FieldRemoveItem.bytes(object_id))
        {:reply, {:ok, item}, %{state | items: items}}
    end
  end

  def handle_call({:add_region_skill, position, skill}, _from, state) do
    source_id = Ms2ex.generate_int()

    Field.broadcast(
      state.topic,
      Packets.RegionSkill.add(source_id, position, skill)
    )

    duration = SkillCast.duration(skill)
    Process.send_after(self(), {:remove_region_skill, source_id}, duration + 5000)
    {:reply, :ok, state}
  end

  def handle_call({:add_status, status}, _from, state) do
    Field.broadcast(state.topic, Packets.Buff.send(:add, status))
    Process.send_after(self(), {:remove_status, status}, status.duration)
    {:reply, :ok, state}
  end

  def handle_call({:add_object, :mount, mount}, _from, state) do
    mount = Map.put(mount, :object_id, state.counter)
    mounts = Map.put(state.mounts, mount.character_id, mount)
    {:reply, {:ok, mount}, %{state | counter: state.counter + 1, mounts: mounts}}
  end

  def handle_cast({:enter_battle_stance, character}, state) do
    Field.broadcast(character, Packets.UserBattle.set_stance(character, true))
    Process.send_after(self(), {:leave_battle_stance, character}, 5_000)
    {:noreply, state}
  end

  def handle_info({:add_item, item}, state) do
    {:noreply, add_item(item, state)}
  end

  def handle_info({:remove_region_skill, source_id}, state) do
    Field.broadcast(state.topic, Packets.RegionSkill.remove(source_id))
    {:noreply, state}
  end

  def handle_info({:remove_status, status}, state) do
    Field.broadcast(state.topic, Packets.Buff.send(:remove, status))
    {:noreply, state}
  end

  def handle_info({:add_mob, spawn_group, mob}, state) do
    {:noreply, add_mob(spawn_group, mob, state)}
  end

  def handle_info({:remove_mob, mob}, state) do
    {:noreply, remove_mob(mob, state)}
  end

  def handle_info({:leave_battle_stance, character}, state) do
    Field.broadcast(character, Packets.UserBattle.set_stance(character, false))
    {:noreply, state}
  end

  def handle_info(:send_updates, state) do
    for char_id <- Map.keys(state.sessions) do
      with {:ok, char} <- CharacterManager.lookup(char_id) do
        Field.broadcast(state.topic, Packets.ProxyGameObj.update_player(char))
      end
    end

    for {_id, npc} <- state.npcs do
      Field.broadcast(state.topic, Packets.ControlNpc.control(:npc, npc))
    end

    Process.send_after(self(), :send_updates, @updates_intval)

    {:noreply, state}
  end

  def handle_info(:maybe_stop, state) do
    if Enum.empty?(state.sessions) do
      Logger.info("Field #{state.field_id} @ Channel #{state.channel_id} is empty. Stopping.")
      {:stop, :normal, state}
    else
      {:noreply, state}
    end
  end

  def handle_info({:push, character_id, packet}, state) do
    if session_pid = Map.get(state.sessions, character_id) do
      send(session_pid, {:push, packet})
    end

    {:noreply, state}
  end

  def handle_info(data, state) do
    Logger.warn("[Field] Unknown message: #{inspect(data)}")
    {:noreply, state}
  end
end
