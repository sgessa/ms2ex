defmodule Ms2ex.Schema.CharacterBuff do
  use Ecto.Schema

  import Ecto.Changeset

  schema "character_buffs" do
    belongs_to :character, Ms2ex.Schema.Character

    field :effect_id, :integer
    field :effect_level, :integer, default: 1
    field :stacks, :integer, default: 1
    field :expires_at, :utc_datetime_usec

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(buff, attrs) do
    buff
    |> cast(attrs, [:character_id, :effect_id, :effect_level, :stacks, :expires_at])
    |> validate_required([:character_id, :effect_id, :effect_level, :stacks, :expires_at])
  end
end
