defmodule Ms2ex.Repo.Migrations.CreateCharacterConfigs do
  use Ecto.Migration

  def change do
    create table(:character_configs) do
      add :character_id, references(:characters, on_delete: :delete_all), null: false
      add :key_binds, :binary, null: true

      timestamps(type: :timestamptz)
    end

    create unique_index(:character_configs, [:character_id])
  end
end
