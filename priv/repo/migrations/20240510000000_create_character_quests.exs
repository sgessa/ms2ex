defmodule Ms2ex.Repo.Migrations.CreateCharacterQuests do
  use Ecto.Migration

  def change do
    create table(:character_quests) do
      add :quest_id, :integer, null: false
      add :state, :integer, default: 0, null: false
      add :completion_count, :integer, default: 0, null: false
      add :start_time, :bigint, null: false
      add :end_time, :bigint, default: 0, null: false
      add :track, :boolean, default: false, null: false
      add :conditions, :map, default: %{}, null: false
      add :owner_id, :binary_id, null: false
      add :is_account_quest, :boolean, default: false, null: false

      timestamps()
    end

    create index(:character_quests, [:owner_id])
    create index(:character_quests, [:quest_id])
    create index(:character_quests, [:owner_id, :quest_id, :is_account_quest], unique: true)
    create index(:character_quests, [:state])
  end
end
