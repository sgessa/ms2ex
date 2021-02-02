defmodule Ms2ex.Repo.Migrations.CreateHotBars do
  use Ecto.Migration

  def change do
    create table(:hot_bars) do
      add :character_id, references(:characters, on_delete: :delete_all), null: false
      add :active, :boolean, null: false
      add :quick_slots, :binary, null: false
    end

    create index(:hot_bars, [:character_id])
  end
end
