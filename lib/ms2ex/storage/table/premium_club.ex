defmodule Ms2ex.Storage.Tables.PremiumClub do
  alias Ms2ex.Storage

  @table_name "vip.xml"

  def all do
    case Storage.get(:table, @table_name) do
      %{table: table} -> table
      _ -> %{}
    end
  end

  def buffs, do: Map.get(all(), :buffs, %{})
  def items, do: Map.get(all(), :items, %{})
  def packages, do: Map.get(all(), :packages, %{})

  def benefit(id), do: Map.get(items(), to_string(id))
  def package(id), do: Map.get(packages(), to_string(id))
end
