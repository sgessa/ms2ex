defmodule Ms2ex.Repo.Migrations.CreateChatStickerGroups do
  use Ecto.Migration

  def change do
    create table(:chat_sticker_groups) do
      add :character_id, references(:characters, on_delete: :delete_all), null: false

      add :expires_at, :timestamptz
      add :group_id, :integer, null: false
    end

    create index(:chat_sticker_groups, [:character_id])
    create unique_index(:chat_sticker_groups, [:character_id, :group_id])
  end
end
