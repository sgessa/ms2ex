defmodule Ms2ex.Storage.Tables.ExpTable do
  alias Ms2ex.Storage

  @table_name "exp.xml"

  @doc "Returns `{:ok, exp_to_next_level}` for a character level, or :error."
  @spec to_next_level(pos_integer()) :: {:ok, non_neg_integer()} | :error
  def to_next_level(level) do
    :table
    |> Storage.get(@table_name)
    |> get_in([:table, :next_exp, to_string(level)])
    |> case do
      nil -> :error
      tnl when is_integer(tnl) -> {:ok, tnl}
      _ -> :error
    end
  end
end
