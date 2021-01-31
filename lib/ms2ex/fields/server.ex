defmodule Ms2ex.FieldServer do
  use GenServer

  require Logger

  alias Ms2ex.{Field, FieldHelper, Packets, Registries}

  import FieldHelper

  @updates_intval 1000

  def init({character, session}) do
    Logger.info("Start Field #{character.map_id} @ Channel #{session.channel_id}")

    send(self(), {:add_character, character})
    send(self(), :send_updates)

    {:ok, initialize_state(character.map_id, session.channel_id)}
  end

  def handle_call({:add_object, :mount, mount}, _from, state) do
    mount = Map.put(mount, :object_id, state.counter)
    mounts = Map.put(state.mounts, mount.character_id, mount)
    {:reply, {:ok, mount}, %{state | counter: state.counter + 1, mounts: mounts}}
  end

  def handle_call({:remove_character, character_id}, _from, state) do
    state = remove_character(character_id, state)
    send(self(), :maybe_stop)
    {:reply, :ok, state}
  end

  def handle_info(:send_updates, state) do
    character_ids = Map.keys(state.sessions)

    for {_id, char} <- Registries.Characters.lookup(character_ids) do
      Field.broadcast(self(), Packets.ProxyGameObj.update_player(char))
    end

    Process.send_after(self(), :send_updates, @updates_intval)

    {:noreply, state}
  end

  def handle_info({:add_character, character}, state) do
    {:noreply, add_character(character, state)}
  end

  def handle_info({:broadcast, packet, sender_pid}, state) do
    for {_char_id, pid} <- state.sessions, pid != sender_pid do
      send(pid, {:push, packet})
    end

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

  def handle_info({:DOWN, _, _, pid, _reason}, state) do
    case Enum.find(state.sessions, fn {_, char_pid} -> pid == char_pid end) do
      {char_id, _} ->
        state = remove_character(char_id, state)
        send(self(), :maybe_stop)
        {:noreply, state}

      _ ->
        {:noreply, state}
    end
  end
end
