defmodule Ms2ex.Storage.Tables.FieldMission do
  alias Ms2ex.Storage

  @table_name "fieldmission.xml"

  def get(mission_count) when is_integer(mission_count) do
    Storage.get(:table, @table_name)
    |> get_in([:table, :entries, to_string(mission_count)])
  end

  def reached_progress(completed_missions) when is_integer(completed_missions) do
    Storage.get(:table, @table_name)
    |> get_in([:table, :entries])
    |> Map.values()
    |> Enum.map(& &1.mission_count)
    |> Enum.filter(&(&1 <= completed_missions))
    |> Enum.max(fn -> 0 end)
  end
end
