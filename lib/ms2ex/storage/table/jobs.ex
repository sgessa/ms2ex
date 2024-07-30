defmodule Ms2ex.Storage.Tables.Jobs do
  alias Ms2ex.Storage.Metadata

  def all() do
    :table
    |> Metadata.get("job.xml")
    |> get_in([:table, :entries])
  end
end
