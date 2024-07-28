defmodule Ms2ex.Metadata do
  def get(module, id) do
    prefix = Macro.underscore(module)
    key = "#{prefix}:#{id}"

    Ms2ex.Redix
    |> Redix.command!(["GET", key])
    |> :erlang.binary_to_term()
  end
end
