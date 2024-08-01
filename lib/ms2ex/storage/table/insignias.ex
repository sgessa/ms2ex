defmodule Ms2ex.Storage.Tables.Insignias do
  alias Ms2ex.{Enums, Storage}

  def get(id) do
    :table
    |> Storage.get("nametagsymbol.xml")
    |> get_in([:table, :entries])
    |> Map.get("#{id}")
    |> then(&Map.put(&1, :type, Enums.InsigniaType.get_key(&1.type)))
  end
end
