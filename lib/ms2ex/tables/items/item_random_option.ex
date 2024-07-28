defmodule Ms2ex.Tables.ItemRandomOption do
  alias Ms2ex.Metadata

  def lookup(static_id, rarity) do
    Metadata.get(Ms2ex.Metadata.Table, "itemoptionrandom.xml")
    |> Map.get(:table)
    |> Map.get(:options, %{})
    |> Map.get(static_id, %{})
    |> Map.get(rarity, nil)
  end
end
