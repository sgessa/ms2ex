defmodule Ms2ex.Tables.ItemConstantOption do
  alias Ms2ex.Metadata

  def lookup(constant_id, rarity) do
    Metadata.get(Ms2ex.Metadata.Table, "itemoptionconstant.xml")
    |> Map.get(:table)
    |> Map.get(:options, %{})
    |> Map.get(constant_id, %{})
    |> Map.get(rarity, nil)
  end
end
