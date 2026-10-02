defmodule Ms2ex.Schema.AccountStorage do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key false
  schema "account_storages" do
    field :account_id, :integer, primary_key: true
    field :mesos, :integer, default: 0
    field :expand, :integer, default: 0

    timestamps(type: :utc_datetime)
  end

  def changeset(storage, attrs) do
    storage
    |> cast(attrs, [:account_id, :mesos, :expand])
    |> validate_required([:account_id])
  end
end
