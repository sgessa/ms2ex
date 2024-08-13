defmodule Ms2ex.Storage.Table.MagicPaths do
  alias Ms2ex.Storage

  def get(id) do
    :table
    |> Storage.get("magicpath.xml")
    |> get_in([:table, :entries, "#{id}"])
  end
end
