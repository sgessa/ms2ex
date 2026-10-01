defmodule Ms2ex.Repo.Migrations.CreateCharacterShopData do
  use Ecto.Migration

  def change do
    create table(:character_shop_data) do
      add :owner_id, :bigint, null: false
      add :shop_id, :integer, null: false
      add :restock_time, :bigint, null: false, default: 0
      add :restock_count, :integer, null: false, default: 0
      add :interval, :integer, null: false, default: 0

      timestamps(type: :timestamptz)
    end

    create index(:character_shop_data, [:owner_id])
    create index(:character_shop_data, [:owner_id, :shop_id], unique: true)

    create table(:character_shop_item_data) do
      add :owner_id, :bigint, null: false
      add :shop_id, :integer, null: false
      add :shop_item_id, :integer, null: false
      add :stock_purchased, :integer, null: false, default: 0
      add :item, :bytea, null: false

      timestamps(type: :timestamptz)
    end

    create index(:character_shop_item_data, [:owner_id])
    create index(:character_shop_item_data, [:owner_id, :shop_id, :shop_item_id], unique: true)
  end
end
