defmodule Ms2ex.Storage.Tables.Shop do
  @moduledoc """
  Vendor shop metadata: one entry per shop id, with the restock policy for
  limited-stock shops (`enable_reset`).
  """

  alias Ms2ex.Storage

  @table_name "server.shop.xml"

  @spec get_meta(integer()) :: map() | nil
  def get_meta(shop_id) do
    case Storage.get(:table, @table_name) do
      %{} = shops -> Map.get(shops, shop_id)
      _ -> nil
    end
  end
end
