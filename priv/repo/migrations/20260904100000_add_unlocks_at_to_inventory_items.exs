defmodule Ms2ex.Repo.Migrations.AddUnlocksAtToInventoryItems do
  use Ecto.Migration

  def change do
    alter table(:inventory_items) do
      add :unlocks_at, :utc_datetime
    end
  end
end
