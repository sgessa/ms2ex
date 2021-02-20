defmodule Ms2ex.ChatSticker do
  use Ecto.Schema
  import Ecto.Changeset

  schema "chat_stickers" do
    belongs_to :character, Ms2ex.Character

    field :favorited, :boolean, default: false
    field :group_id, :integer
    field :sticker_id, :integer

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(emote, attrs) do
    emote
    |> cast(attrs, [:favorited, :group_id, :sticker_id])
    |> validate_required([:favorited, :group_id, :sticker_id])
  end
end
