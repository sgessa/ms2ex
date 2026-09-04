defmodule Ms2ex.Storage.Tables.AutoActions do
  alias Ms2ex.Storage

  @doc """
  Price package for an auto-action, e.g. the paid extensions offered while
  fishing or playing an instrument.
  """
  @spec lookup(String.t(), integer()) :: {:ok, map()} | :error
  def lookup(content, package_id) do
    :table
    |> Storage.get("autoactionpricepackage.xml")
    |> get_in([:table, :entries, content, to_string(package_id)])
    |> case do
      nil -> :error
      package -> {:ok, package}
    end
  end
end
