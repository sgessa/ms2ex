defmodule Ms2ex.Repo.Migrations.CreateCharacterConfigs do
  use Ecto.Migration

  def up do
    create table(:character_configs) do
      add :character_id, references(:characters, on_delete: :delete_all), null: false
      add :key_binds, :binary
      add :guide_records, :binary
      add :gathering_counts, :binary
      add :instant_revive_count, :integer, default: 0, null: false

      timestamps(type: :timestamptz)
    end

    create unique_index(:character_configs, [:character_id])

    alter table(:characters) do
      remove :guide_records
      remove :gathering_counts
      remove :instant_revive_count
    end
  end

  def down do
    alter table(:characters) do
      add :guide_records, :binary
      add :gathering_counts, :binary
      add :instant_revive_count, :integer, default: 0, null: false
    end

    drop table(:character_configs)
  end
end
