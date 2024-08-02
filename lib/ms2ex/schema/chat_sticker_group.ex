defmodule Ms2ex.ChatStickerGroup do
  use Ecto.Schema

  import Ecto.Changeset

  schema "chat_sticker_groups" do
    belongs_to :character, Ms2ex.Character

    field :group_id, :integer
  end

  @doc false
  def changeset(emote, attrs) do
    emote
    |> cast(attrs, [:group_id])
    |> validate_required([:group_id])
  end
end
