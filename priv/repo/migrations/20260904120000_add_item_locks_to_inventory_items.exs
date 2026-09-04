defmodule Ms2ex.Repo.Migrations.AddItemLocksToInventoryItems do
  use Ecto.Migration

  def change do
    alter table(:inventory_items) do
      add :is_locked, :boolean, null: false, default: false
      add :unlocks_at, :utc_datetime
    end
  end
end
