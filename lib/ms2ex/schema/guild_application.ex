defmodule Ms2ex.Schema.GuildApplication do
  use Ecto.Schema

  alias Ms2ex.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @fields [
    :guild_id,
    :character_id,
    :account_id
  ]

  @required [:guild_id, :character_id, :account_id]

  schema "guild_applications" do
    belongs_to :guild, Schema.Guild
    belongs_to :character, Schema.Character
    belongs_to :account, Schema.Account

    timestamps(type: :utc_datetime)
  end

  def changeset(application, attrs) do
    application
    |> cast(attrs, @fields)
    |> validate_required(@required)
    |> unique_constraint([:guild_id, :character_id])
  end
end
