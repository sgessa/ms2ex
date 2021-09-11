defmodule Ms2ex.PartyManager do
  use GenServer

  alias Ms2ex.PartyServer

  def create(leader), do: call({:create, leader})

  def lookup(character), do: call({:lookup, character})

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def init(:ok) do
    {:ok, %{}}
  end

  def handle_call({:create, leader}, _from, state) do
    {:ok, pid} = PartyServer.start(leader)
    Process.monitor(pid)
    {:ok, party} = PartyServer.lookup(pid)
    {:reply, {:ok, party}, Map.put(state, leader.id, %{party_id: party.id, pid: pid})}
  end

  def handle_call({:lookup, character}, _from, state) do
    case Map.get(state, character.id) do
      %{party_id: party_id} -> {:reply, {:ok, party_id}, state}
      _ -> {:reply, :error, state}
    end
  end

  def handle_info({:DOWN, _, _, pid, _reason}, state) do
    state =
      state
      |> Enum.reject(fn {_, %{pid: party_pid}} -> party_pid == pid end)
      |> Enum.into(%{})

    {:noreply, state}
  end

  defp call(msg), do: GenServer.call(__MODULE__, msg)
end
