defmodule Ms2ex.Schema.CharacterQuest do
  @moduledoc """
  Schema for character quests.

  This schema stores information about quests that a character has accepted,
  including their progress, state, and completion time.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "character_quests" do
    field :quest_id, :integer

    field :state, Ecto.Enum,
      values: [:none, :started, :completed, :failed, :abandoned],
      default: :none

    field :completion_count, :integer, default: 0
    field :start_time, :integer
    field :end_time, :integer, default: 0
    field :track, :boolean, default: false
    field :conditions, :map, default: %{}

    field :owner_id, :binary_id
    field :is_account_quest, :boolean, default: false

    # Virtual field for quest metadata
    field :metadata, :any, virtual: true

    timestamps()
  end

  @required_fields [:quest_id, :state, :owner_id, :is_account_quest]
  @optional_fields [:completion_count, :start_time, :end_time, :track, :conditions]

  @doc """
  Changeset for character quests.
  """
  def changeset(quest, attrs) do
    quest
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
  end
end
