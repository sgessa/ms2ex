defmodule Ms2ex.Schema.PremiumMembership do
  use Ecto.Schema

  import Ecto.Changeset

  schema "premium_memberships" do
    belongs_to :account, Ms2ex.Schema.Account

    field :expires_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(premium_memberships, attrs) do
    premium_memberships
    |> cast(attrs, [:account_id, :expires_at])
    |> validate_required([:account_id, :expires_at])
  end
end
