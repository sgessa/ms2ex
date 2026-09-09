defmodule Ms2ex.Schema.GuildMember do
  use Ecto.Schema

  alias Ms2ex.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @fields [
    :guild_id,
    :character_id,
    :rank,
    :message,
    :weekly_contribution,
    :total_contribution,
    :daily_donation_count,
    :checkin_at,
    :donation_at
  ]

  @required [:guild_id, :character_id, :rank]

  @primary_key false
  schema "guild_members" do
    belongs_to :guild, Schema.Guild, primary_key: true
    belongs_to :character, Schema.Character, primary_key: true

    field :rank, :integer, default: 4
    field :message, :string, default: ""
    field :weekly_contribution, :integer, default: 0
    field :total_contribution, :integer, default: 0
    field :daily_donation_count, :integer, default: 0
    field :checkin_at, :utc_datetime
    field :donation_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  def changeset(member, attrs) do
    member
    |> cast(attrs, @fields)
    |> validate_required(@required)
    |> unique_constraint(:character_id)
  end
end
