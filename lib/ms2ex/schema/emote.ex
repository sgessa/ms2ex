defmodule Ms2ex.Schema.Emote do
  use Ecto.Schema
  import Ecto.Changeset
  alias Ms2ex.Schema

  schema "emotes" do
    belongs_to :character, Schema.Character

    field :emote_id, :integer

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(emote, attrs) do
    emote
    |> cast(attrs, [:emote_id])
    |> validate_required([:emote_id])
  end
end
