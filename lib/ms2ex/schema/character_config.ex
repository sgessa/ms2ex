defmodule Ms2ex.Schema.CharacterConfig do
  use Ecto.Schema

  import Ecto.Changeset

  alias Ms2ex.EctoTypes
  alias Ms2ex.Schema

  @type t :: %__MODULE__{}

  @config_fields [
    :key_binds,
    :guide_records,
    :gathering_counts,
    :mastery_rewards_claimed,
    :instant_revive_count
  ]

  schema "character_configs" do
    belongs_to :character, Schema.Character

    field :key_binds, EctoTypes.Term, default: %{}
    field :guide_records, EctoTypes.Term, default: %{}
    field :gathering_counts, EctoTypes.Term, default: %{}
    field :mastery_rewards_claimed, EctoTypes.Term, default: %{}
    field :instant_revive_count, :integer, default: 0

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(config, attrs) do
    cast(config, attrs, @config_fields)
  end
end
