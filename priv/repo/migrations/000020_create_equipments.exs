defmodule Ms2ex.Repo.Migrations.CreateEquipments do
  use Ecto.Migration

  def change do
    create table(:equipments) do
      add :character_id, references(:characters, on_delete: :delete_all), null: false
      add :ears_id, references(:inventory_items, on_delete: :delete_all)
      add :face_id, references(:inventory_items, on_delete: :delete_all)
      add :face_decor_id, references(:inventory_items, on_delete: :delete_all)
      add :hair_id, references(:inventory_items, on_delete: :delete_all)
      add :top_id, references(:inventory_items, on_delete: :delete_all)
      add :bottom_id, references(:inventory_items, on_delete: :delete_all)
      add :shoes_id, references(:inventory_items, on_delete: :delete_all)
    end

    create unique_index(:equipments, [:character_id])
    create index(:equipments, [:ears_id])
    create index(:equipments, [:face_id])
    create index(:equipments, [:face_decor_id])
    create index(:equipments, [:hair_id])
    create index(:equipments, [:top_id])
    create index(:equipments, [:bottom_id])
    create index(:equipments, [:shoes_id])
  end
end
