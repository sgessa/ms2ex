defmodule Ms2ex.Context.ChatStickers do
  @moduledoc """
  Context module for managing chat stickers.
  """

  alias Ms2ex.{Repo, Schema}

  import Ecto.Query, except: [update: 2]

  @doc """
  Lists all sticker groups for a given character.

  Returns a list of group IDs.

  ## Examples

      iex> list_groups(character)
      [1, 2, 3]
  """
  @spec list_groups(Schema.Character.t()) :: [integer()]
  def list_groups(%Schema.Character{id: character_id}) do
    Schema.ChatStickerGroup
    |> where([s], s.character_id == ^character_id)
    |> group_by([s], s.group_id)
    |> select([s], s.group_id)
    |> Repo.all()
  end

  @doc """
  Gets a specific sticker group for a character by group ID.

  Returns the chat sticker group if found, otherwise nil.

  ## Examples

      iex> get(character, 1)
      %Schema.ChatStickerGroup{}

      iex> get(character, 999)
      nil
  """
  @spec get(Schema.Character.t(), integer()) :: Schema.ChatStickerGroup.t() | nil
  def get(%Schema.Character{id: character_id}, group_id) do
    Repo.get_by(Schema.ChatStickerGroup, character_id: character_id, group_id: group_id)
  end

  @doc """
  Adds a sticker group to a character.

  ## Examples

      iex> add(character, 1)
      {:ok, %Schema.ChatStickerGroup{}}

      iex> add(character, 1) # when already exists
      {:error, %Ecto.Changeset{}}
  """
  @spec add(Schema.Character.t(), integer()) ::
          {:ok, Schema.ChatStickerGroup.t()} | {:error, Ecto.Changeset.t()}
  def add(%Schema.Character{} = character, group_id) do
    character
    |> Ecto.build_assoc(:stickers)
    |> Schema.ChatStickerGroup.changeset(%{group_id: group_id})
    |> Repo.insert()
  end

  @doc """
  Lists all favorited stickers for a character.

  Returns a list of sticker IDs.

  ## Examples

      iex> list_favorited(character)
      [101, 102, 103]
  """
  @spec list_favorited(Schema.Character.t()) :: [integer()]
  def list_favorited(%Schema.Character{id: character_id}) do
    Schema.FavoriteChatSticker
    |> where([s], s.character_id == ^character_id)
    |> select([s], s.sticker_id)
    |> Repo.all()
  end

  @doc """
  Marks a sticker as favorite for a character.

  ## Examples

      iex> favorite(character, 101, 1)
      {:ok, %Schema.FavoriteChatSticker{}}
  """
  @spec favorite(Schema.Character.t(), integer(), integer()) ::
          {:ok, Schema.FavoriteChatSticker.t()} | {:error, Ecto.Changeset.t()}
  def favorite(%Schema.Character{} = character, sticker_id, group_id) do
    character
    |> Ecto.build_assoc(:favorite_stickers)
    |> Schema.FavoriteChatSticker.changeset(%{sticker_id: sticker_id, group_id: group_id})
    |> Repo.insert()
  end

  @doc """
  Removes a sticker from a character's favorites.

  ## Examples

      iex> unfavorite(character, 101)
      {1, nil}
  """
  @spec unfavorite(Schema.Character.t(), integer()) :: {non_neg_integer(), nil | [term()]}
  def unfavorite(%Schema.Character{id: character_id}, sticker_id) do
    Schema.FavoriteChatSticker
    |> where([s], s.character_id == ^character_id and s.sticker_id == ^sticker_id)
    |> Repo.delete_all()
  end

  @default_stickers 1..3

  @doc """
  Returns the list of default sticker IDs available to all characters.

  ## Examples

      iex> default_stickers()
      1..3
  """
  @spec default_stickers() :: Range.t()
  def default_stickers(), do: @default_stickers
end
