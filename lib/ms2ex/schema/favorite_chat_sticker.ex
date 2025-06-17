defmodule Ms2ex.Schema.FavoriteChatSticker do
  use Ecto.Schema

  alias Ms2ex.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "favorite_chat_stickers" do
    belongs_to :character, Schema.Character
    belongs_to :group, Schema.ChatStickerGroup

    field :sticker_id, :integer
  end

  @doc false
  def changeset(favorite_chat_sticker, attrs) do
    favorite_chat_sticker
    |> cast(attrs, [:group_id, :sticker_id])
    |> validate_required([:group_id, :sticker_id])
    |> unique_constraint(:sticker_id,
      name: :favorite_chat_stickers_character_id_group_id_sticker_id_index
    )
  end
end
