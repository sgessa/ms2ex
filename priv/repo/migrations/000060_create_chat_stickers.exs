defmodule Ms2ex.Repo.Migrations.CreateChatStickers do
  use Ecto.Migration

  def change do
    create table(:chat_stickers) do
      add :character_id, references(:characters, on_delete: :delete_all), null: false

      add :expires_at, :timestamptz
      add :favorited, :boolean, null: false
      add :group_id, :integer, null: false

      timestamps(type: :timestamptz)
    end

    create index(:chat_stickers, [:character_id])
    create unique_index(:chat_stickers, [:character_id, :group_id])
  end
end
