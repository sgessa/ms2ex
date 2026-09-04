defmodule Ms2ex.Repo.Migrations.CreateCharacterBuffs do
  use Ecto.Migration

  def change do
    create table(:character_buffs) do
      add :character_id, references(:characters, on_delete: :delete_all), null: false
      add :effect_id, :integer, null: false
      add :effect_level, :integer, null: false, default: 1
      add :stacks, :integer, null: false, default: 1
      add :expires_at, :utc_datetime_usec, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:character_buffs, [:character_id])
    create unique_index(:character_buffs, [:character_id, :effect_id])
  end
end
