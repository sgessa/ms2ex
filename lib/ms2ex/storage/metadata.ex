defmodule Ms2ex.Storage.Metadata do
  def filter(set, key) do
    Ms2ex.Redix
    |> Redix.command!(["KEYS", "#{set}:#{key}"])
    |> Enum.map(&["GET", &1])
    |> then(&Redix.pipeline!(Ms2ex.Redix, &1))
    |> Enum.map(&:erlang.binary_to_term/1)
  end
end
