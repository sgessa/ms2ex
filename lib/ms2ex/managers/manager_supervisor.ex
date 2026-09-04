defmodule Ms2ex.Managers.ManagerSupervisor do
  @moduledoc """
  Owns the per-character managers (character, inventory, quest, achievement).

  Children are temporary: each one is started when its character logs in and
  removed when the character disconnects — a crashed manager stays down until
  the next login rather than restarting with partially stale state.

  The quest and achievement managers trap exits and flush their deferred
  writes in terminate, so both a disconnect and the application teardown
  persist everything held in memory between periodic flushes.
  """
  use DynamicSupervisor

  def start_link(init_arg),
    do: DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)

  @doc "Starts a per-character manager under this supervisor."
  def start_child(module, character, name) do
    child_spec = %{
      id: name,
      start: {module, :start_link, [character]},
      restart: :temporary
    }

    DynamicSupervisor.start_child(__MODULE__, child_spec)
  end

  @doc """
  Stops a manager process and removes it from the supervisor. No-op for a
  process that already exited.
  """
  def terminate_child(pid) when is_pid(pid) do
    case DynamicSupervisor.terminate_child(__MODULE__, pid) do
      :ok -> :ok
      {:error, :not_found} -> :ok
    end
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
