defmodule Ms2ex.Emote do
  use Ecto.Schema
  import Ecto.Changeset

  schema "emotes" do
    belongs_to :character, Ms2ex.Character

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
