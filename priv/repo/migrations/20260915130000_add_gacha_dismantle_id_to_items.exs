defmodule Ms2ex.Repo.Migrations.AddGachaDismantleIdToItems do
  use Ecto.Migration

  def change do
    alter table(:inventory_items) do
      add :gacha_dismantle_id, :integer, null: false, default: 0
    end
  end
end
