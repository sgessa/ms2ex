defmodule Ms2ex.Storage.Tables.IndividualDropItem do
  alias Ms2ex.Storage

  @doc """
  Resolves an individual drop box id to its drop groups, keyed by group id.
  """
  def get(box_id) do
    Storage.get(:table, "individualdropitem.xml")
    |> get_in([:table, :entries, to_string(box_id)])
    |> case do
      nil -> %{}
      groups -> groups
    end
  end
end
