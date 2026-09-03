defmodule Ms2ex.Repo.Migrations.AddItemLockedToInventoryItems do
  use Ecto.Migration

  def change do
    alter table(:inventory_items) do
      add :is_locked, :boolean, null: false, default: false
    end
  end
end
