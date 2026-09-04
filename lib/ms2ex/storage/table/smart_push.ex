defmodule Ms2ex.Storage.Tables.SmartPush do
  alias Ms2ex.Storage

  @spec lookup(pos_integer()) :: {:ok, map()} | :error
  def lookup(smart_push_id) do
    :table
    |> Storage.get("smartpush.xml")
    |> get_in([:table, :entries, to_string(smart_push_id)])
    |> case do
      nil -> :error
      entry -> {:ok, entry}
    end
  end
end
