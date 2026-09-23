defmodule Ms2ex.Repo.Migrations.CreateCharacterConfigs do
  use Ecto.Migration

  def up do
    create table(:character_configs) do
      add :character_id, references(:characters, on_delete: :delete_all), null: false
      add :key_binds, :binary, null: true
      add :guide_records, :binary, null: true
      add :gathering_counts, :binary, null: true
      add :instant_revive_count, :integer, default: 0, null: false

      timestamps(type: :timestamptz)
    end

    create unique_index(:character_configs, [:character_id])

    # carry the per-character values over: existing config rows first, then
    # characters that have no config row yet
    execute """
            UPDATE character_configs cc
            SET guide_records = c.guide_records,
                gathering_counts = c.gathering_counts,
                instant_revive_count = c.instant_revive_count
            FROM characters c
            WHERE cc.character_id = c.id
            """,
            """
            UPDATE characters c
            SET guide_records = cc.guide_records,
                gathering_counts = cc.gathering_counts,
                instant_revive_count = cc.instant_revive_count
            FROM character_configs cc
            WHERE cc.character_id = c.id
            """

    execute """
            INSERT INTO character_configs
              (character_id, guide_records, gathering_counts, instant_revive_count, inserted_at, updated_at)
            SELECT c.id, c.guide_records, c.gathering_counts, c.instant_revive_count, now(), now()
            FROM characters c
            WHERE (c.guide_records IS NOT NULL OR c.gathering_counts IS NOT NULL OR c.instant_revive_count > 0)
              AND NOT EXISTS (SELECT 1 FROM character_configs cc WHERE cc.character_id = c.id)
            """,
            "DELETE FROM character_configs"

    alter table(:characters) do
      remove :guide_records
      remove :gathering_counts
      remove :instant_revive_count
    end
  end

  def down do
    alter table(:characters) do
      add :guide_records, :binary, null: true
      add :gathering_counts, :binary, null: true
      add :instant_revive_count, :integer, default: 0, null: false
    end

    execute """
            UPDATE characters c
            SET guide_records = cc.guide_records,
                gathering_counts = cc.gathering_counts,
                instant_revive_count = cc.instant_revive_count
            FROM character_configs cc
            WHERE cc.character_id = c.id
            """

    drop table(:character_configs)
  end
end
