defmodule Ms2ex.Storage.Tables.Jobs do
  alias Ms2ex.Enums
  alias Ms2ex.Storage

  def all do
    case Storage.get(:table, "job.xml") do
      nil -> %{}
      doc -> get_in(doc, [:table, :entries]) || %{}
    end
  end

  def get(job) do
    Map.get(all(), to_job_id(job))
  end

  @doc """
  The per-job character tutorial: the starting field, the skip field/item,
  the maps and taxis unlocked on completion, and the starter/reward items.
  """
  def tutorial(job) do
    get(job)[:tutorial]
  end

  # entries are keyed by numeric job id; callers pass enums like :wizard
  defp to_job_id(job) when is_integer(job), do: job
  defp to_job_id(job) when is_atom(job), do: Enums.Job.get_value(job)
end
