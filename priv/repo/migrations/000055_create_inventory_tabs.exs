defmodule Ms2ex.Repo.Migrations.CreateInventoryTabs do
  use Ecto.Migration

  def change do
    create table(:inventory_tabs) do
      add :character_id, references(:characters, on_delete: :delete_all), null: false
      add :slots, :integer, null: false
      add :tab, :integer, null: false
    end

    create index(:inventory_tabs, [:character_id])
    create unique_index(:inventory_tabs, [:character_id, :tab])
  end
end
