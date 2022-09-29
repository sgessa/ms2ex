defmodule Ms2ex.Repo.Migrations.CreateInventory do
  use Ecto.Migration

  def change do
    create table(:inventory_items) do
      add :character_id, references(:characters, on_delete: :delete_all), null: false
      add :item_id, :bigint, null: false

      add :amount, :integer, null: false
      add :color, :binary
      add :data, :binary
      add :enchants, :integer, null: false
      add :equip_slot, :integer, null: false
      add :inventory_slot, :integer
      add :inventory_tab, :integer, null: false
      add :location, :integer, null: false
      add :level, :integer, null: false
      add :rarity, :integer, null: false
      add :enchant_level, :integer, null: false
      add :transfer_flags, :integer, null: false
      add :stats, :map, null: true

      timestamps(type: :timestamptz)
    end

    create index(:inventory_items, [:character_id])
    create unique_index(:inventory_items, [:character_id, :inventory_slot, :inventory_tab])
  end
end
