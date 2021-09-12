defmodule Ms2ex.SessionManager do
  use GenServer

  def lookup(account_id), do: call({:lookup, account_id})

  def register(account_id, tags), do: call({:register, account_id, tags})

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def init(:ok) do
    {:ok, %{}}
  end

  def handle_call({:lookup, account_id}, _from, state) do
    case Map.get(state, account_id) do
      nil -> {:reply, :error, state}
      meta -> {:reply, {:ok, meta}, state}
    end
  end

  def handle_call({:register, account_id, meta}, {pid, _}, state) do
    existing_pids = get_in(state, [account_id, :pids]) || []

    if pid in existing_pids do
      meta = Map.put(meta, :pids, existing_pids)
      {:reply, :ok, Map.put(state, account_id, meta)}
    else
      Process.monitor(pid)
      new_pids = [pid | existing_pids]
      meta = Map.put(meta, :pids, new_pids)
      {:reply, :ok, Map.put(state, account_id, meta)}
    end
  end

  def handle_info({:DOWN, _, _, pid, _reason}, state) do
    res =
      Enum.find(state, fn {_id, meta} ->
        Enum.member?(meta.pids, pid)
      end)

    case res do
      {account_id, meta} ->
        # Untrack session PID
        pids = List.delete(meta.pids, pid)

        # Update account metadata
        meta = %{meta | pids: pids}
        {:noreply, Map.put(state, account_id, meta)}

      _ ->
        {:noreply, state}
    end
  end

  defp call(msg), do: GenServer.call(__MODULE__, msg)
end
