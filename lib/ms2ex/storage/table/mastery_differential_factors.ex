defmodule Ms2ex.Storage.Tables.MasteryDifferentialFactors do
  @moduledoc """
  `masterydifferentialfactor.xml`: how much mastery a harvest still awards
  when the recipe sits below the player's grade. Only the number of entries
  with a positive factor is used: once the grade difference reaches it, the
  harvest awards no mastery at all.
  """

  alias Ms2ex.Storage

  @table_name "masterydifferentialfactor.xml"

  @spec entries() :: %{integer() => %{differential: integer(), factor: integer()}}
  def entries do
    :table
    |> Storage.get(@table_name)
    |> get_in([:table, :entries]) || %{}
  end

  @spec positive_factor_count() :: non_neg_integer()
  def positive_factor_count do
    entries()
    |> Enum.count(fn {_id, entry} -> Map.get(entry, :factor, 0) > 0 end)
  end
end
