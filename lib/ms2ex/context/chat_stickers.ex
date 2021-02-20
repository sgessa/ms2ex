defmodule Ms2ex.ChatStickers do
  alias Ms2ex.{Character, ChatSticker, Repo}

  import Ecto.Query, except: [update: 2]

  @default_stickers 1..7

  def list_groups(%Character{id: character_id}) do
    ChatSticker
    |> where([s], s.character_id == ^character_id)
    |> group_by([s], s.group_id)
    |> select([s], s.group_id)
    |> Repo.all()
  end

  def get(%Character{id: character_id}, sticker_id) do
    Repo.get_by(ChatSticker, character_id: character_id, sticker_id: sticker_id)
  end

  def add(%Character{} = character, sticker_id) do
    character
    |> Ecto.build_assoc(:stickers)
    |> ChatSticker.changeset(%{sticker_id: sticker_id})
    |> Repo.insert()
  end

  def favorite(%ChatSticker{} = sticker, is_favorited) do
    sticker
    |> ChatSticker.changeset(%{favorited: is_favorited})
    |> Repo.update()
  end

  def default_stickers(), do: @default_stickers
end
