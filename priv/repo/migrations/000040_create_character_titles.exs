defmodule Ms2ex.Repo.Migrations.CreateCharacterTitles do
  use Ecto.Migration

  def change do
    create table(:character_titles) do
      add :character_id, references(:characters, on_delete: :delete_all), null: false
      add :title_id, :integer, null: false

      timestamps(type: :timestamptz)
    end

    create index(:character_titles, [:character_id])
    create unique_index(:character_titles, [:character_id, :title_id])
  end
end
