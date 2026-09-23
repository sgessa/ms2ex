defmodule Ms2ex.Repo.Migrations.MoveInstantReviveCountToCharacterConfigs do
  use Ecto.Migration

  def change do
    alter table(:character_configs) do
      add :instant_revive_count, :integer, default: 0, null: false
    end

    execute """
            INSERT INTO character_configs (character_id, instant_revive_count, inserted_at, updated_at)
            SELECT ch.id, ch.instant_revive_count, now(), now()
            FROM characters ch
            WHERE ch.instant_revive_count > 0
              AND NOT EXISTS (SELECT 1 FROM character_configs c WHERE c.character_id = ch.id)
            """,
            "UPDATE characters SET instant_revive_count = 0"

    execute """
            UPDATE character_configs c
            SET instant_revive_count = ch.instant_revive_count
            FROM characters ch
            WHERE c.character_id = ch.id AND ch.instant_revive_count > 0
            """,
            """
            UPDATE characters ch
            SET instant_revive_count = c.instant_revive_count
            FROM character_configs c
            WHERE c.character_id = ch.id
            """

    alter table(:characters) do
      remove :instant_revive_count
    end
  end
end
