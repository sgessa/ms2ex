defmodule Ms2ex.Storage.Tables.Jobs do
  alias Ms2ex.Storage

  def all() do
    :table
    |> Storage.get("job.xml")
    |> get_in([:table, :entries])
  end

  def get(job) do
    :table
    |> Storage.get("job.xml")
    |> get_in([:table, :entries, job])
  end
end
