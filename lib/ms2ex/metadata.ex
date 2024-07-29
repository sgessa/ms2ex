defmodule Ms2ex.Metadata do
  def get(struct, id) when is_struct(struct),
    do: get(struct.__struct__, id)

  def get(module, ids) when is_list(ids) do
    get(module, Enum.join(ids, "_"))
  end

  def get(module, id) when is_atom(module) do
    prefix = Macro.underscore(module)
    key = "#{prefix}:#{id}"

    Ms2ex.Redix
    |> Redix.command!(["GET", key])
    |> :erlang.binary_to_term()
  end

  def filter(module, key) do
    prefix = Macro.underscore(module)
    key = "#{prefix}:#{key}"

    Ms2ex.Redix
    |> Redix.command!(["KEYS", key])
    |> Enum.map(&["GET", &1])
    |> then(&Redix.pipeline!(Ms2ex.Redix, &1))
    |> Enum.map(&:erlang.binary_to_term/1)
  end

  def all(module), do: filter(module, "*")
end
