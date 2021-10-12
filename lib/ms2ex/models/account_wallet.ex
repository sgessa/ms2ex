defmodule Ms2ex.AccountWallet do
  use Ecto.Schema

  import Ecto.Changeset

  schema "account_wallets" do
    belongs_to :account, Ms2ex.Account

    field :event_merets, :integer, default: 0
    field :game_merets, :integer, default: 0
    field :merets, :integer, default: 100
    field :meso_tokens, :integer, default: 0
  end

  @doc false
  def changeset(wallet, attrs) do
    wallet
    |> cast(attrs, [:event_merets, :game_merets, :merets, :meso_tokens])
    |> validate_required([:event_merets, :game_merets, :merets, :meso_tokens])
  end
end
