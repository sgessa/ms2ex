defmodule Ms2ex.Storage.Tables.Insignias do
  alias Ms2ex.Enums
  alias Ms2ex.Storage

  @spec get(integer()) :: {:ok, map()} | :error
  def get(id) do
    :table
    |> Storage.get("nametagsymbol.xml")
    |> get_in([:table, :entries, to_string(id)])
    |> case do
      nil -> :error
      entry -> {:ok, Map.put(entry, :type, Enums.InsigniaType.get_key(entry.type))}
    end
  end
end
