defmodule Ms2ex.Schema.CharacterShopItemData do
  use Ecto.Schema

  import Ecto.Changeset

  alias Ms2ex.EctoTypes

  schema "character_shop_item_data" do
    field :owner_id, :integer
    field :shop_id, :integer
    field :shop_item_id, :integer
    field :stock_purchased, :integer, default: 0
    # the rolled item instance stocked for this entry (kept until restock)
    field :item, EctoTypes.Term

    timestamps(type: :utc_datetime)
  end

  def changeset(shop_item_data, attrs) do
    shop_item_data
    |> cast(attrs, [:owner_id, :shop_id, :shop_item_id, :stock_purchased, :item])
    |> validate_required([:owner_id, :shop_id, :shop_item_id, :item])
  end
end
