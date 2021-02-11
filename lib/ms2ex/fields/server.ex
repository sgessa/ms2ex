defmodule Ms2ex.FieldServer do
  use GenServer

  require Logger

  alias Ms2ex.{FieldHelper, Packets, World}

  import FieldHelper

  @updates_intval 1000

  def init({character, session}) do
    Logger.info("Start Field #{character.map_id} @ Channel #{session.channel_id}")

    send(self(), :send_updates)

    {
      :ok,
      initialize_state(session.world, character.map_id, session.channel_id),
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
    item = Map.put(item, :object_id, state.counter)
    items = Map.put(state.items, state.counter, item)

    broadcast(state.sessions, Packets.FieldAddItem.bytes(item))

    {:reply, {:ok, item}, %{state | counter: state.counter + 1, items: items}}
  end

  def handle_call({:remove_item, object_id}, _from, state) do
    case Map.get(state.items, object_id) do
      nil ->
        {:reply, :error, state}

      item ->
        items = Map.delete(state.items, object_id)
        broadcast(state.sessions, Packets.FieldRemoveItem.bytes(object_id))
        {:reply, {:ok, item}, %{state | items: items}}
    end
  end

  def handle_call({:add_object, :mount, mount}, _from, state) do
    mount = Map.put(mount, :object_id, state.counter)
    mounts = Map.put(state.mounts, mount.character_id, mount)
    {:reply, {:ok, mount}, %{state | counter: state.counter + 1, mounts: mounts}}
  end

  def handle_info(:send_updates, state) do
    character_ids = Map.keys(state.sessions)

    for {_id, npc} <- state.npcs do
      broadcast(state.sessions, Packets.ControlNpc.bytes(npc))
    end

    for {_id, char} <- World.get_characters(state.world, character_ids) do
      broadcast(state.sessions, Packets.ProxyGameObj.update_player(char))
    end

    Process.send_after(self(), :send_updates, @updates_intval)

    {:noreply, state}
  end

  def handle_info({:broadcast, packet, sender_pid}, state) do
    broadcast(state.sessions, packet, sender_pid)
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
end
