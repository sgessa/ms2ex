defmodule Ms2ex.Schema.CharacterShopData do
  use Ecto.Schema

  import Ecto.Changeset

  schema "character_shop_data" do
    # the account id or the character id, depending on the shop's
    # account_wide restock policy
    field :owner_id, :integer
    field :shop_id, :integer
    field :restock_time, :integer, default: 0
    field :restock_count, :integer, default: 0
    # reset interval of the shop (Enums.ResetType)
    field :interval, :integer, default: 0

    timestamps(type: :utc_datetime)
  end

  def changeset(shop_data, attrs) do
    shop_data
    |> cast(attrs, [:owner_id, :shop_id, :restock_time, :restock_count, :interval])
    |> validate_required([:owner_id, :shop_id])
  end
end
