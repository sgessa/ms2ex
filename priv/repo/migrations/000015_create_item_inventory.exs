defmodule Ms2ex.Repo.Migrations.CreateInventory do
  use Ecto.Migration

  def change do
    create table(:inventory_items) do
      add :character_id, references(:characters, on_delete: :delete_all), null: false
      add :item_id, :bigint, null: false

      add :amount, :integer, null: false
      add :color, :binary
      add :data, :binary
      add :location, :integer, null: false

      timestamps(type: :timestamptz)
    end

    create index(:inventory_items, [:character_id])
  end
end
