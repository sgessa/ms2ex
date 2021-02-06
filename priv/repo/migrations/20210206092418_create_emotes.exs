defmodule Ms2ex.Repo.Migrations.CreateEmotes do
  use Ecto.Migration

  def change do
    create table(:emotes) do
      add :character_id, references(:characters, on_delete: :delete_all), null: false
      add :emote_id, :integer, null: false

      timestamps(type: :timestamptz)
    end

    create index(:emotes, [:character_id])
    create unique_index(:emotes, [:character_id, :emote_id])
  end
end
