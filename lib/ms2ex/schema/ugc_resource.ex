defmodule Ms2ex.Schema.UgcResource do
  use Ecto.Schema

  alias Ms2ex.Enums
  alias Ms2ex.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @fields [:character_id, :path, :type]

  schema "ugc_resources" do
    belongs_to :character, Schema.Character

    field :path, :string, default: ""
    field :type, Enums.UgcType, default: :none

    timestamps(type: :utc_datetime)
  end

  def changeset(resource, attrs) do
    resource
    |> cast(attrs, @fields)
    |> validate_required([:character_id, :type])
  end
end
