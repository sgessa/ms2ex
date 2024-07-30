defmodule Ms2ex.Storage.Tables.Insignias do
  alias Ms2ex.Storage.Metadata
  alias Ms2ex.Enums

  def get(id) do
    :table
    |> Metadata.get("nametagsymbol.xml")
    |> get_in([:table, :entries])
    |> Map.get("#{id}")
    |> then(&Map.put(&1, :type, Enums.InsigniaType.get_key(&1.type)))
  end
end
