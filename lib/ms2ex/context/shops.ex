defmodule Ms2ex.Context.Shops do
  @moduledoc """
  Persists per-owner vendor shop state: the restock window of limited-stock
  shops and the stock-purchase counters of their items. `owner_id` is the
  account id or the character id, depending on the shop's restock policy.
  """

  alias Ms2ex.Repo
  alias Ms2ex.Schema

  import Ecto.Query, except: [update: 2]

  def list_shop_data(owner_id) do
    Repo.all(from d in Schema.CharacterShopData, where: d.owner_id == ^owner_id)
  end

  def create_shop_data(attrs) do
    %Schema.CharacterShopData{}
    |> Schema.CharacterShopData.changeset(attrs)
    |> Repo.insert()
  end

  def delete_shop_data(owner_id, shop_id) do
    Repo.delete_all(
      from d in Schema.CharacterShopData,
        where: d.owner_id == ^owner_id and d.shop_id == ^shop_id
    )
  end

  def list_shop_item_data(owner_id) do
    Repo.all(from d in Schema.CharacterShopItemData, where: d.owner_id == ^owner_id)
  end

  def create_shop_item_data(attrs) do
    %Schema.CharacterShopItemData{}
    |> Schema.CharacterShopItemData.changeset(attrs)
    |> Repo.insert()
  end

  def delete_shop_item_data(owner_id, shop_id, shop_item_id) do
    Repo.delete_all(
      from d in Schema.CharacterShopItemData,
        where:
          d.owner_id == ^owner_id and d.shop_id == ^shop_id and
            d.shop_item_id == ^shop_item_id
    )
  end

  def save_shop_data(%Schema.CharacterShopData{} = data) do
    data
    |> Ecto.Changeset.change(restock_time: data.restock_time, restock_count: data.restock_count)
    |> Repo.update()
  end

  def save_shop_item_data(%Schema.CharacterShopItemData{} = data) do
    data
    |> Ecto.Changeset.change(stock_purchased: data.stock_purchased)
    |> Repo.update()
  end
end
