defmodule Ms2ex.Storage.Tables.SmartPush do
  alias Ms2ex.Storage

  @spec lookup(pos_integer()) :: {:ok, map()} | :error
  def lookup(smart_push_id) do
    :table
    |> Storage.get("smartpush.xml")
    |> get_in([:table, :entries, to_string(smart_push_id)])
    |> case do
      nil -> :error
      entry -> {:ok, entry}
    end
  end

  @doc """
  The additional effect a smart push content grants, e.g. the buff that keeps
  a mount from throwing its rider in water.
  """
  @spec effect_id(String.t()) :: integer() | nil
  def effect_id(content) do
    :table
    |> Storage.get("smartpush.xml")
    |> get_in([:table, :entries])
    |> Kernel.||(%{})
    |> Enum.find_value(fn
      {_id, %{content: ^content, value: value}} -> value
      _ -> nil
    end)
  end
end
