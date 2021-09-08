defmodule Ms2ex.Friend do
  use Ecto.Schema

  import Ecto.Changeset
  import EctoEnum

  defenum(Status, pending: 0, accepted: 1, blocked: 2)

  schema "friends" do
    belongs_to :character, Ms2ex.Character
    belongs_to :rcpt, Ms2ex.Character

    field :block_reason, :string, default: ""
    field :message, :string, default: ""
    field :is_request, :boolean, default: false
    field :shared_id, :integer
    field :status, Status

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
