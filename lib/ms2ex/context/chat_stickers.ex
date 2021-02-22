defmodule Ms2ex.ChatStickers do
  alias Ms2ex.{Character, ChatStickerGroup, FavoriteChatSticker, Repo}

  import Ecto.Query, except: [update: 2]

  def list_groups(%Character{id: character_id}) do
    ChatStickerGroup
    |> where([s], s.character_id == ^character_id)
    |> group_by([s], s.group_id)
    |> select([s], s.group_id)
    |> Repo.all()
  end

  def get(%Character{id: character_id}, group_id) do
    Repo.get_by(ChatStickerGroup, character_id: character_id, group_id: group_id)
  end

  def add(%Character{} = character, group_id) do
    character
    |> Ecto.build_assoc(:stickers)
    |> ChatStickerGroup.changeset(%{group_id: group_id})
    |> Repo.insert()
  end

  def list_favorited(%Character{id: character_id}) do
    FavoriteChatSticker
    |> where([s], s.character_id == ^character_id)
    |> select([s], s.sticker_id)
    |> Repo.all()
  end

  def favorite(%Character{} = character, sticker_id, group_id) do
    character
    |> Ecto.build_assoc(:favorite_stickers)
    |> FavoriteChatSticker.changeset(%{sticker_id: sticker_id, group_id: group_id})
    |> Repo.insert()
  end

  def unfavorite(%Character{id: character_id}, sticker_id) do
    FavoriteChatSticker
    |> where([s], s.character_id == ^character_id and s.sticker_id == ^sticker_id)
    |> Repo.delete_all()
  end

  @default_stickers 1..3
  def default_stickers(), do: @default_stickers
end
