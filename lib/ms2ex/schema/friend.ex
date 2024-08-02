defmodule Ms2ex.Schema.Friend do
  use Ecto.Schema

  alias Ms2ex.Schema

  import Ecto.Changeset

  schema "friends" do
    belongs_to :character, Schema.Character
    belongs_to :rcpt, Schema.Character

    field :block_reason, :string, default: ""
    field :message, :string, default: ""
    field :is_request, :boolean, default: false
    field :shared_id, :integer
    field :status, Ecto.Enum, values: [pending: 0, accepted: 1, blocked: 2]

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(friend, attrs) do
    friend
    |> cast(attrs, [:block_reason, :message, :is_request, :status])
    |> validate_required([:shared_id, :status])
    |> unique_constraint(:rcpt, name: :friends_character_id_rcpt_id_index)
  end

  @doc false
  def add(friend, rcpt, attrs) do
    friend
    |> cast(attrs, [:message, :is_request, :shared_id, :status])
    |> put_assoc(:rcpt, rcpt)
    |> validate_required([:message, :shared_id, :status])
    |> unique_constraint(:rcpt, name: :friends_character_id_rcpt_id_index)
  end

  @doc false
  def block(friend, rcpt, attrs) do
    friend
    |> cast(attrs, [:block_reason, :shared_id, :status])
    |> put_assoc(:rcpt, rcpt)
    |> validate_required([:block_reason, :shared_id, :status])
    |> unique_constraint(:rcpt, name: :friends_character_id_rcpt_id_index)
  end

  @doc false
  def block_friend(friend, reason) do
    friend
    |> change(status: :blocked, block_reason: reason)
    |> validate_required([:block_reason, :shared_id, :status])
  end
end
