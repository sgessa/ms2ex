defmodule Ms2ex.Schema.CharacterTitle do
  use Ecto.Schema
  import Ecto.Changeset
  alias Ms2ex.Schema

  schema "character_titles" do
    belongs_to :character, Schema.Character

    field :title_id, :integer

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(character_title, attrs) do
    character_title
    |> cast(attrs, [:title_id])
    |> validate_required([:title_id])
  end
end
