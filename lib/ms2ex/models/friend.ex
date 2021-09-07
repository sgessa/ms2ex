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
    field :shared_id, :integer
    field :status, Status, default: :pending

    timestamps(type: :utc_datetime)
  end

  @doc false
  def add(friend, rcpt, attrs) do
    friend
    |> cast(attrs, [:block_reason, :message, :shared_id, :status])
    |> put_assoc(:rcpt, rcpt)
    |> validate_required([:message, :shared_id, :status])
    |> unique_constraint(:rcpt, name: :friends_character_id_rcpt_id_index)
  end
end
