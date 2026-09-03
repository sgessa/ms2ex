defmodule Ms2ex.Storage.Tables.UgcDesign do
  @moduledoc """
  Cost and rarity of the design shop templates a player can turn into an item.
  """

  alias Ms2ex.Enums
  alias Ms2ex.Storage

  def get(item_id) do
    :table
    |> Storage.get("ugcdesign.xml")
    |> get_in([:table, :entries])
    |> Map.get("#{item_id}")
    |> case do
      nil -> nil
      entry -> Map.put(entry, :currency_type, currency(entry))
    end
  end

  defp currency(%{currency_type: type}) when is_integer(type) do
    Enums.MeretMarketCurrency.get_key(type)
  end

  defp currency(%{currency_type: type}), do: type
end
