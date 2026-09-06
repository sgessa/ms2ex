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

  @doc "Returns the base exp for killing a mob of the given level, or nil."
  def mob_exp(level) do
    get_in(Storage.get(:table, @table_name), [:table, :exp_base, "2", to_string(level)])
  end

  @doc """
  Base exp for an exp type at a level: `commonexp.xml` maps the type to one of
  the `exp*.xml` tables plus a factor applied on top.
  """
  @spec typed_exp(atom(), pos_integer()) :: non_neg_integer()
  def typed_exp(exp_type, level) do
    with %{exp_table_id: table_id, factor: factor} <- common_entry(exp_type),
         value when is_integer(value) <-
           get_in(Storage.get(:table, @table_name), [
             :table,
             :exp_base,
             to_string(table_id),
             to_string(level)
           ]) do
      trunc(value * factor)
    else
      _ -> 0
    end
  end

  defp common_entry(exp_type) do
    :table
    |> Storage.get("commonexp.xml")
    |> get_in([:table, :entries, exp_type])
  end
end
