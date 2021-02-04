defmodule Ms2ex.World do
  use GenServer

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def broadcast(world, packet, sender_pid \\ nil) do
    Swarm.send(world, {:broadcast, packet, sender_pid})
  end

  def get_character(world, character_id) do
    call(world, {:get_character, character_id})
  end

  def get_characters(world, ids) do
    call(world, {:get_characters, ids})
  end

  def get_character_by_name(world, character_id) do
    call(world, {:get_character, character_id})
  end

  def update_character(world, character) do
    call(world, {:update_character, character})
  end

  def monitor_character(world, character) do
    call(world, {:monitor, character})
  end

  def init(:ok) do
    state = %{characters: %{}}

    {:ok, state}
  end

  def handle_call({:get_character, character_id}, _from, state) do
    if character = Map.get(state.characters, character_id) do
      {:reply, {:ok, character}, state}
    else
      {:reply, :error, state}
    end
  end

  def handle_call({:get_characters, ids}, _from, state) do
    characters = Enum.filter(state.characters, fn {id, _char} -> id in ids end)
    {:reply, characters, state}
  end

  def handle_call({:get_character_by_name, character_name}, _from, state) do
    if character = Enum.find(state.characters, fn {_id, char} -> char.name == character_name end) do
      {:reply, {:ok, character}, state}
    else
      {:reply, :error, state}
    end
  end

  def handle_call({:update_character, character}, _from, state) do
    characters = Map.put(state.characters, character.id, character)
    {:reply, :ok, %{state | characters: characters}}
  end

  def handle_call({:monitor, character}, _from, state) do
    Process.monitor(character.session_pid)
    {:reply, :ok, state}
  end

  def handle_info({:broadcast, packet, sender_pid}, state) do
    for {_char_id, %{session_pid: pid}} <- state.characters, pid != sender_pid do
      send(pid, {:push, packet})
    end

    {:noreply, state}
  end

  def handle_info({:DOWN, _, _, pid, _reason}, state) do
    character =
      Enum.find(state.characters, fn {_, %{session_pid: char_pid}} -> pid == char_pid end)

    characters =
      if character do
        Map.delete(state.characters, character.id)
      else
        state.characters
      end

    {:noreply, %{state | characters: characters}}
  end

  defp call(world, msg) do
    GenServer.call({:via, :swarm, world}, msg)
  end
end
