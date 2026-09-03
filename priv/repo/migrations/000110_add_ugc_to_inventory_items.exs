defmodule Ms2ex.Repo.Migrations.AddUgcToInventoryItems do
  use Ecto.Migration

  def change do
    alter table(:inventory_items) do
      add :ugc, :binary
    end
  end
end
