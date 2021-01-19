defmodule Ms2ex.Field do
  use GenServer

  require Logger

  alias Ms2ex.Packets

  @counter 100_000
  @updates_intval 1000

  def find_or_create(session) do
    %{character: character, channel_id: channel_id} = session
    name = build_name(character.map_id, channel_id)

    case Process.whereis(name) do
      nil ->
        GenServer.start(__MODULE__, session, name: name)

      pid ->
        send(pid, {:add_character, character, session.pid})
        {:ok, pid}
    end
  end

  def broadcast(pid, packet, sender_id \\ nil), do: send(pid, {:broadcast, packet, sender_id})

  def init(session) do
    %{character: character, channel_id: channel_id} = session

    Logger.info("Start Field #{character.map_id} @ Channel #{channel_id}")

    send(self(), {:add_character, character, session.pid})
    send(self(), :send_updates)

    {:ok,
     %{
       counter: @counter,
       field_id: character.map_id,
       channel_id: channel_id,
       characters: []
     }}
  end

  # TODO
  def handle_info(:send_updates, state) do
    # session_count = length(state.characters)
    # Logger.debug("Field #{state.field_id}: Sending 0 packets to #{session_count} players")

    Process.send_after(self(), :send_updates, @updates_intval)

    {:noreply, state}
  end

  def handle_info({:add_character, character, session_pid}, %{characters: characters} = state) do
    Process.monitor(session_pid)

    character = Map.put(character, :session_pid, session_pid)

    Logger.info("Field #{state.field_id} @ Channel #{state.channel_id}: #{character.name} joined")

    character = %{character | object_id: state.counter}
    state = %{state | counter: state.counter + 1}
    characters = [character | characters]

    broadcast(self(), Packets.FieldAddUser.bytes(character))
    broadcast(self(), Packets.ProxyGameObj.load_player(character))

    {:noreply, %{state | characters: characters}}
  end

  def handle_info({:broadcast, packet, sender_id}, state) do
    for char <- state.characters,
        &(!sender_id || &1.id != sender_id),
        do: send(char.session_pid, {:push, packet})

    {:noreply, state}
  end

  def handle_info({:DOWN, _, _, pid, _reason}, state) do
    character_index = Enum.find_index(state.characters, &(&1.session_pid == pid))
    maybe_remove_character(character_index, state)
  end

  defp build_name(field_id, channel_id), do: :"field:#{field_id}:channel:#{channel_id}"

  defp maybe_remove_character(nil, state), do: {:noreply, state}

  defp maybe_remove_character(idx, state) do
    character = Enum.at(state.characters, idx)

    if character do
      characters = List.delete_at(state.characters, idx)
      Logger.info("Field #{state.field_id} @ Channel #{state.channel_id}: #{character.name} left")
      maybe_stop_server(characters, state)
    else
      {:noreply, state}
    end
  end

  defp maybe_stop_server(characters, state) when length(characters) < 1 do
    Logger.info("Field #{state.field_id} @ Channel #{state.channel_id} is empty. Stopping.")
    {:stop, :normal, state}
  end

  defp maybe_stop_server(characters, state) do
    {:noreply, %{state | characters: characters}}
  end
end
