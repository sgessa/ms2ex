defmodule Ms2ex.Storage.Tables.Jobs do
  alias Ms2ex.Enums
  alias Ms2ex.Storage

  def all do
    :table
    |> Storage.get("job.xml")
    |> get_in([:table, :entries])
  end

  def get(job) do
    all()
    |> Map.get(to_job_id(job))
  end

  # entries are keyed by numeric job id; callers pass enums like :wizard
  defp to_job_id(job) when is_integer(job), do: job
  defp to_job_id(job) when is_atom(job), do: Enums.Job.get_value(job)
end
