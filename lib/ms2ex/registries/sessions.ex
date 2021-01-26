defmodule Ms2ex.Registries.Sessions do
  use GenServer

  @table_name :session_registry

  def lookup(account_id), do: call({:lookup, account_id})

  def register(account_id, tags), do: call({:register, account_id, tags})

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def init(:ok) do
    :ets.new(@table_name, [:private, :set, :named_table])
    {:ok, nil}
  end

  def handle_call({:lookup, account_id}, _from, state) do
    case :ets.lookup(@table_name, account_id) do
      [{_account_id, tags} | _] -> {:reply, {:ok, tags}, state}
      _ -> {:reply, :error, state}
    end
  end

  def handle_call({:register, account_id, tags}, _from, state) do
    if :ets.insert(@table_name, {account_id, tags}) do
      {:reply, :ok, state}
    else
      {:reply, :error, state}
    end
  end

  defp call(msg) do
    GenServer.call({:via, :swarm, __MODULE__}, msg)
  end
end
