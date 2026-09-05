defmodule Ms2ex.Storage.Tables.MasteryRewards do
  @moduledoc """
  `mastery.xml`: per mastery type, the mastery value each grade starts at and
  the reward box handed out for reaching it.
  """

  alias Ms2ex.Storage

  @table_name "mastery.xml"

  @type entry :: %{
          value: integer(),
          item_id: integer(),
          item_rarity: integer(),
          item_amount: integer()
        }

  @spec grades(atom()) :: %{integer() => entry()}
  def grades(type) when is_atom(type) do
    :table
    |> Storage.get(@table_name)
    |> get_in([:table, :entries, type]) || %{}
  end

  @spec lookup(atom(), integer()) :: {:ok, entry()} | :error
  def lookup(type, grade) do
    case Map.get(grades(type), grade) do
      nil -> :error
      entry -> {:ok, entry}
    end
  end

  @doc """
  The grade a mastery value has reached: the highest grade whose starting
  value the mastery covers, never below 1.
  """
  @spec grade(atom(), integer()) :: integer()
  def grade(type, mastery) do
    type
    |> grades()
    |> Enum.filter(fn {_grade, entry} -> mastery >= entry.value end)
    |> Enum.map(&elem(&1, 0))
    |> Enum.max(fn -> 1 end)
    |> max(1)
  end
end
