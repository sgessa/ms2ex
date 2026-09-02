defmodule Ms2ex.Storage.Tables.UserStats do
  alias Ms2ex.Enums.Job
  alias Ms2ex.Storage

  @table_name "userstat.xml"

  @doc "Returns the metadata base stats for a job and level, or nil."
  @spec get(atom(), pos_integer()) :: map() | nil
  def get(job, level) do
    with job_code when is_integer(job_code) <- Job.get_value(job),
         table when is_map(table) <- Storage.get(:table, @table_name),
         jobs when is_map(jobs) <- Map.get(table, :jobs) || get_in(table, [:table, :jobs]),
         levels when is_map(levels) <- Map.get(jobs, job_code),
         stats when is_map(stats) <- Map.get(levels, to_string(level)) do
      stats
    else
      _ -> nil
    end
  end
end
