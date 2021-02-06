defmodule Ms2ex.Wallet do
  use Ecto.Schema

  import Ecto.Changeset

  @types %{
    event_merets: 0x9,
    game_merets: 0x8,
    havi_fruits: 0x6,
    merets: 0x7,
    mesos: 0x0,
    meso_tokens: 0x10,
    rues: 0x5,
    trevas: 0x4,
    valor_tokens: 0x3
  }

  schema "wallets" do
    belongs_to :character, Ms2ex.Character

    field :event_merets, :integer, default: 0
    field :game_merets, :integer, default: 0
    field :havi_fruits, :integer, default: 0
    field :merets, :integer, default: 100
    field :mesos, :integer, default: 10_000
    field :meso_tokens, :integer, default: 0
    field :rues, :integer, default: 0
    field :trevas, :integer, default: 0
    field :valor_tokens, :integer, default: 0
  end

  @doc false
  def changeset(wallet, attrs) do
    wallet
    |> cast(attrs, fields())
    |> validate_required(fields())
  end

  def currency_type(currency), do: Map.get(@types, currency)

  defp fields(), do: Map.keys(@types)
end
