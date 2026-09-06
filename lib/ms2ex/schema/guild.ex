defmodule Ms2ex.Schema.Guild do
  use Ecto.Schema

  alias Ms2ex.EctoTypes
  alias Ms2ex.Enums
  alias Ms2ex.Schema
  alias Ms2ex.Types

  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @fields [
    :name,
    :emblem,
    :notice,
    :focus,
    :experience,
    :funds,
    :house_rank,
    :house_theme,
    :capacity,
    :leader_id,
    :ranks,
    :buffs,
    :posters,
    :npcs,
    :bank
  ]

  @required [:name, :leader_id, :ranks]

  schema "guilds" do
    field :name, :string
    field :emblem, :string, default: ""
    field :notice, :string, default: ""
    field :focus, Enums.GuildFocus, default: :none
    field :experience, :integer, default: 0
    field :funds, :integer, default: 0
    field :house_rank, :integer, default: 0
    field :house_theme, :integer, default: 0
    field :capacity, :integer, default: 60

    field :ranks, EctoTypes.Term, default: Types.GuildRank.default_ranks()
    field :buffs, EctoTypes.Term, default: []
    field :posters, EctoTypes.Term, default: []
    field :npcs, EctoTypes.Term, default: []
    field :bank, EctoTypes.Term, default: []

    belongs_to :leader, Schema.Character, foreign_key: :leader_id
    has_many :members, Schema.GuildMember, foreign_key: :guild_id
    has_many :applications, Schema.GuildApplication, foreign_key: :guild_id

    timestamps(type: :utc_datetime)
  end

  def changeset(guild, attrs) do
    guild
    |> cast(attrs, @fields)
    |> validate_required(@required)
    |> unique_constraint(:name)
  end
end
