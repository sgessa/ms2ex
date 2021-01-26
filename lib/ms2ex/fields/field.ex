defmodule Ms2ex.Field do
  use GenServer

  require Logger

  alias Ms2ex.{Packets, Registries}

  @counter 100_000
  @updates_intval 1000

  def find_or_create(character, session) do
    name = field_name(character.map_id, session.channel_id)

    case Process.whereis(name) do
      nil ->
        GenServer.start(__MODULE__, {character, session}, name: name)

      pid ->
        send(pid, {:add_character, character, session.pid})
        {:ok, pid}
    end
  end

  def broadcast(field_pid, packet, sender_pid \\ nil) do
    send(field_pid, {:broadcast, packet, sender_pid})
  end

  def init({character, session}) do
    Logger.info("Start Field #{character.map_id} @ Channel #{session.channel_id}")

    send(self(), {:add_character, character, session.pid})
    send(self(), :send_updates)

    {:ok,
     %{
       counter: @counter,
       field_id: character.map_id,
       channel_id: session.channel_id,
       sessions: %{}
     }}
  end

  def handle_info(:send_updates, state) do
    character_ids = Map.keys(state.sessions)

    for {_id, char} <- Registries.Characters.lookup(character_ids) do
      broadcast(self(), Packets.ProxyGameObj.update_player(char))
    end

    Process.send_after(self(), :send_updates, @updates_intval)

    {:noreply, state}
  end

  def handle_info({:add_character, character, session_pid}, state) do
    Process.monitor(session_pid)

    Logger.info("Field #{state.field_id} @ Channel #{state.channel_id}: #{character.name} joined")

    character_ids = Map.keys(state.sessions)

    for {_id, char} <- Registries.Characters.lookup(character_ids) do
      push(session_pid, Packets.FieldAddUser.bytes(char))
      push(session_pid, Packets.ProxyGameObj.load_player(char))
    end

    character = Map.put(character, :object_id, state.counter)
    Registries.Characters.update(character)

    state = %{state | counter: state.counter + 1}

    broadcast(self(), Packets.FieldAddUser.bytes(character))
    broadcast(self(), Packets.ProxyGameObj.load_player(character))

    sessions = Map.put(state.sessions, character.id, session_pid)
    {:noreply, %{state | sessions: sessions}}
  end

  def handle_info({:broadcast, packet, sender_pid}, state) do
    for {_char_id, pid} <- state.sessions, pid != sender_pid do
      push(pid, packet)
    end

    {:noreply, state}
  end

  def handle_info({:DOWN, _, _, pid, _reason}, state) do
    case Enum.find(state.sessions, fn {_, char_pid} -> pid == char_pid end) do
      {char_id, _} -> remove_session(char_id, state)
      _ -> {:noreply, state}
    end
  end

  defp field_name(field_id, channel_id), do: :"field:#{field_id}:channel:#{channel_id}"

  defp remove_session(char_id, state) do
    sessions = Map.delete(state.sessions, char_id)

    with {:ok, char} <- Registries.Characters.lookup(char_id) do
      Logger.info("Field #{state.field_id} @ Channel #{state.channel_id}: #{char.name} left")
      broadcast(self(), Packets.FieldRemoveUser.bytes(char))
    end

    maybe_stop_server(sessions, state)
  end

  defp maybe_stop_server(sessions, state) when length(sessions) < 1 do
    Logger.info("Field #{state.field_id} @ Channel #{state.channel_id} is empty. Stopping.")
    {:stop, :normal, state}
  end

  defp maybe_stop_server(sessions, state) do
    {:noreply, %{state | sessions: sessions}}
  end

  defp push(pid, packet), do: send(pid, {:push, packet})
end
