defmodule Ms2ex.Storage.Tables.GlobalDropItemBox do
  alias Ms2ex.Storage

  @doc """
  Resolves a global drop box id to its item groups and the shared item-set
  table. Returns `%{groups: [map], items: %{group_id => [map]}}`.
  """
  def get(box_id) do
    table = Storage.get(:table, "globaldropitembox.xml")

    groups = get_in(table, [:table, :drop_groups, to_string(box_id)]) || []
    items = get_in(table, [:table, :items]) || %{}

    %{groups: groups, items: items}
  end
end
