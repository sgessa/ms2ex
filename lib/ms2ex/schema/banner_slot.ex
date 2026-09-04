defmodule Ms2ex.Schema.BannerSlot do
  use Ecto.Schema

  alias Ms2ex.Schema

  import Ecto.Changeset

  @fields [:banner_id, :date, :hour, :character_id, :ugc_resource_id]

  schema "banner_slots" do
    belongs_to :character, Schema.Character
    belongs_to :ugc_resource, Schema.UgcResource

    field :banner_id, :integer
    field :date, :integer
    field :hour, :integer

    timestamps(type: :utc_datetime)
  end

  def changeset(slot, attrs) do
    slot
    |> cast(attrs, @fields)
    |> validate_required([:banner_id, :date, :hour, :character_id])
    |> unique_constraint([:banner_id, :date, :hour])
  end
end
