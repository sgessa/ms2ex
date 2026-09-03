defmodule Ms2ex.Storage.Tables.InteractObjects do
  alias Ms2ex.Storage

  @table_name "interactobject.xml"

  def get(interact_id) do
    :table
    |> Storage.get(@table_name)
    |> get_in([:table, :entries, interact_id])
  end
end
