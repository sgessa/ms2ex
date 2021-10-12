defmodule Ms2ex.Wallet do
  use Ecto.Schema

  import Ecto.Changeset

  schema "wallets" do
    belongs_to :character, Ms2ex.Character

    field :havi_fruits, :integer, default: 0
    field :mesos, :integer, default: 10_000
    field :rues, :integer, default: 0
    field :trevas, :integer, default: 0
    field :valor_tokens, :integer, default: 0
  end

  @doc false
  def changeset(wallet, attrs) do
    wallet
    |> cast(attrs, [:havi_fruits, :mesos, :rues, :trevas, :valor_tokens])
    |> validate_required([:havi_fruits, :mesos, :rues, :trevas, :valor_tokens])
  end
end
