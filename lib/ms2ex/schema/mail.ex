defmodule Ms2ex.Schema.Mail do
  use Ecto.Schema

  alias Ms2ex.EctoTypes
  alias Ms2ex.Enums
  alias Ms2ex.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @fields [
    :sender_id,
    :sender_name,
    :receiver_id,
    :receiver_type,
    :type,
    :title,
    :content,
    :title_args,
    :content_args,
    :wedding_invite,
    :mesos,
    :mesos_collected_at,
    :merets,
    :merets_collected_at,
    :game_merets,
    :game_merets_collected_at,
    :read_at,
    :expires_at
  ]

  @required [:receiver_id, :type, :expires_at]

  schema "mails" do
    field :sender_id, :integer, default: 0
    field :sender_name, :string, default: ""
    field :receiver_id, :integer
    field :receiver_type, Ecto.Enum, values: [character: 0, account: 1], default: :character
    field :type, Enums.MailType, default: :player

    field :title, :string, default: ""
    field :content, :string, default: ""
    field :title_args, EctoTypes.Term, default: []
    field :content_args, EctoTypes.Term, default: []
    field :wedding_invite, :string, default: ""

    field :mesos, :integer, default: 0
    field :mesos_collected_at, :utc_datetime
    field :merets, :integer, default: 0
    field :merets_collected_at, :utc_datetime
    field :game_merets, :integer, default: 0
    field :game_merets_collected_at, :utc_datetime

    field :read_at, :utc_datetime
    field :expires_at, :utc_datetime

    has_many :items, Schema.Item, foreign_key: :mail_id

    timestamps(type: :utc_datetime)
  end

  def changeset(mail, attrs) do
    mail
    |> cast(attrs, @fields)
    |> validate_required(@required)
  end
end
