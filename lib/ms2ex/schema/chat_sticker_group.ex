defmodule Ms2ex.Schema.ChatStickerGroup do
  use Ecto.Schema

  alias Ms2ex.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "chat_sticker_groups" do
    belongs_to :character, Schema.Character

    field :group_id, :integer
  end

  @doc false
  def changeset(emote, attrs) do
    emote
    |> cast(attrs, [:group_id])
    |> validate_required([:group_id])
  end
end
