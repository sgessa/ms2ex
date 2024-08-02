defmodule Ms2ex.Context.ChatStickers do
  alias Ms2ex.{Repo, Schema}

  import Ecto.Query, except: [update: 2]

  def list_groups(%Schema.Character{id: character_id}) do
    Schema.ChatStickerGroup
    |> where([s], s.character_id == ^character_id)
    |> group_by([s], s.group_id)
    |> select([s], s.group_id)
    |> Repo.all()
  end

  def get(%Schema.Character{id: character_id}, group_id) do
    Repo.get_by(Schema.ChatStickerGroup, character_id: character_id, group_id: group_id)
  end

  def add(%Schema.Character{} = character, group_id) do
    character
    |> Ecto.build_assoc(:stickers)
    |> Schema.ChatStickerGroup.changeset(%{group_id: group_id})
    |> Repo.insert()
  end

  def list_favorited(%Schema.Character{id: character_id}) do
    Schema.FavoriteChatSticker
    |> where([s], s.character_id == ^character_id)
    |> select([s], s.sticker_id)
    |> Repo.all()
  end

  def favorite(%Schema.Character{} = character, sticker_id, group_id) do
    character
    |> Ecto.build_assoc(:favorite_stickers)
    |> Schema.FavoriteChatSticker.changeset(%{sticker_id: sticker_id, group_id: group_id})
    |> Repo.insert()
  end

  def unfavorite(%Schema.Character{id: character_id}, sticker_id) do
    Schema.FavoriteChatSticker
    |> where([s], s.character_id == ^character_id and s.sticker_id == ^sticker_id)
    |> Repo.delete_all()
  end

  @default_stickers 1..3
  def default_stickers(), do: @default_stickers
end
