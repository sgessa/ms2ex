defmodule Ms2ex.Schema.CharacterConfig do
  use Ecto.Schema

  alias Ms2ex.EctoTypes
  alias Ms2ex.Schema

  @type t :: %__MODULE__{}

  schema "character_configs" do
    belongs_to :character, Schema.Character

    field :key_binds, EctoTypes.Term, default: %{}
    field :guide_records, EctoTypes.Term, default: %{}
    field :gathering_counts, EctoTypes.Term, default: %{}
    field :instant_revive_count, :integer, default: 0

    timestamps(type: :utc_datetime)
  end
end
