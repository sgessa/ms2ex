defmodule Ms2ex.Storage.Tables.PetExp do
  @moduledoc """
  `petexp.xml`: exp required per pet level, keyed by pet rarity
  (1 = normal .. 6 = artifact).
  """

  alias Ms2ex.Storage

  @table_name "petexp.xml"

  @doc "Returns `{:ok, exp_to_next_level}` for a pet level and rarity, or :error."
  @spec to_next_level(level :: pos_integer(), rarity :: pos_integer()) ::
          {:ok, non_neg_integer()} | :error
  def to_next_level(level, rarity) do
    :table
    |> Storage.get(@table_name)
    |> get_in([:table, :levels, to_string(level), to_string(rarity)])
    |> case do
      nil -> :error
      tnl when is_integer(tnl) -> {:ok, tnl}
      _ -> :error
    end
  end
end
