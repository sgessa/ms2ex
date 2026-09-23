defmodule Ms2ex.Repo.Migrations.MoveGuideRecordsAndGatheringCountsToCharacterConfigs do
  use Ecto.Migration

  def change do
    alter table(:character_configs) do
      add :guide_records, :binary, null: true
      add :gathering_counts, :binary, null: true
    end

    # carry existing values over: config rows first, then characters that
    # have no config row yet
    execute """
      UPDATE character_configs cc
      SET guide_records = c.guide_records, gathering_counts = c.gathering_counts
      FROM characters c
      WHERE cc.character_id = c.id
    """

    execute """
      INSERT INTO character_configs (character_id, guide_records, gathering_counts, inserted_at, updated_at)
      SELECT c.id, c.guide_records, c.gathering_counts, now(), now()
      FROM characters c
      WHERE (c.guide_records IS NOT NULL OR c.gathering_counts IS NOT NULL)
        AND NOT EXISTS (SELECT 1 FROM character_configs cc WHERE cc.character_id = c.id)
    """

    alter table(:characters) do
      remove :guide_records
      remove :gathering_counts
    end
  end
end
