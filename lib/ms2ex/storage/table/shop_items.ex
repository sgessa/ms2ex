defmodule Ms2ex.Storage.Tables.ShopItems do
  @moduledoc """
  Vendor shop stock entries, grouped by shop id and keyed by the shop item
  id (`sn`) each entry carries in the shop window packets.
  """

  alias Ms2ex.Storage

  @table_name "server.shopitem.xml"

  @doc "Stock entries of a shop keyed by shop item id, or an empty map."
  @spec list(integer()) :: %{integer() => map()}
  def list(shop_id) do
    case Storage.get(:table, @table_name) do
      %{} = shops -> Map.get(shops, shop_id, %{})
      _ -> %{}
    end
  end

  @spec get(integer(), integer()) :: map() | nil
  def get(shop_id, shop_item_id), do: Map.get(list(shop_id), shop_item_id)
end
