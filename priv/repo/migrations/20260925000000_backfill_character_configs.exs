defmodule Ms2ex.Repo.Migrations.BackfillCharacterConfigs do
  use Ecto.Migration

  # every character carries a config row from creation on; characters that
  # existed before the table get one here
  def up do
    execute """
    INSERT INTO character_configs (character_id, instant_revive_count, inserted_at, updated_at)
    SELECT c.id, 0, now(), now()
    FROM characters c
    WHERE NOT EXISTS (
      SELECT 1 FROM character_configs cc WHERE cc.character_id = c.id
    )
    """
  end

  def down do
    :ok
  end
end
