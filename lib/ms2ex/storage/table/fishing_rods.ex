defmodule Ms2ex.Storage.Tables.FishingRods do
  @moduledoc """
  `fishingrod.xml`: keyed by the rod code a fishing rod item carries in its
  `FishingRod` function parameter.
  """

  alias Ms2ex.Storage

  @table_name "fishingrod.xml"

  @type entry :: %{
          item_id: integer(),
          min_mastery: integer(),
          add_mastery: integer(),
          reduce_time: integer()
        }

  @spec lookup(integer()) :: {:ok, entry()} | :error
  def lookup(rod_code) when is_integer(rod_code) do
    :table
    |> Storage.get(@table_name)
    |> get_in([:table, :entries, rod_code])
    |> case do
      nil -> :error
      entry -> {:ok, entry}
    end
  end

  def lookup(_rod_code), do: :error
end
