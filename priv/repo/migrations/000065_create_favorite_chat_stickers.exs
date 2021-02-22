defmodule Ms2ex.Repo.Migrations.CreateFavoriteChatStickers do
  use Ecto.Migration

  def change do
    create table(:favorite_chat_stickers) do
      add :character_id, references(:characters, on_delete: :delete_all), null: false
      add :group_id, references(:chat_sticker_groups, on_delete: :delete_all), null: false
      add :sticker_id, :integer, null: false
    end

    create index(:favorite_chat_stickers, [:character_id, :sticker_id])
    create unique_index(:favorite_chat_stickers, [:character_id, :group_id, :sticker_id])
  end
end
