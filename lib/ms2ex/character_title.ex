defmodule Ms2ex.CharacterTitle do
  use Ecto.Schema
  import Ecto.Changeset

  schema "character_titles" do
    belongs_to :character, Ms2ex.Character

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
