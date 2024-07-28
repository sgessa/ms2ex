defmodule Ms2ex.Tables.ItemPickOption do
  alias Ms2ex.Metadata

  def lookup(pick_id, rarity) do
    Metadata.get(Ms2ex.Metadata.Table, "itemoptionpick.xml")
    |> Map.get(:table)
    |> Map.get(:options, %{})
    |> Map.get(pick_id, %{})
    |> Map.get(rarity, nil)
  end
end
