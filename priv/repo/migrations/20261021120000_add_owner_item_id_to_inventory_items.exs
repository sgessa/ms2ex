defmodule Ms2ex.Repo.Migrations.AddOwnerItemIdToInventoryItems do
  use Ecto.Migration

  def change do
    alter table(:inventory_items) do
      add :owner_item_id, :bigint
    end
  end
end
