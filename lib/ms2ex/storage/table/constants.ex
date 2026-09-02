defmodule Ms2ex.Storage.Tables.Constants do
  alias Ms2ex.Storage

  @table_name "server.constants.xml"

  @doc """
  Returns the value of a server constant (snake_case atom, e.g.
  :recovery_ep_wait_tick), or nil when the table or key is absent.
  """
  @spec get(atom()) :: term() | nil
  def get(key) when is_atom(key) do
    case Storage.get(:table, @table_name) do
      %{} = constants -> Map.get(constants, key)
      _ -> nil
    end
  end
end
