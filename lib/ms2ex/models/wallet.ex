defmodule Ms2ex.Wallet do
  use Ecto.Schema

  import Ecto.Changeset

  @fields [
    :event_merets,
    :game_merets,
    :havi_fruits,
    :merets,
    :mesos,
    :meso_tokens,
    :rues,
    :trevas,
    :valor_tokens
  ]

  @types %{
    mesos: 0x0,
    valor_tokens: 0x3,
    trevas: 0x4,
    rues: 0x5,
    havi_fruits: 0x6,
    merets: 0x7,
    game_merets: 0x8,
    event_merets: 0x9,
    meso_tokens: 0x10
  }

  schema "wallets" do
    belongs_to :character, Ms2ex.Character

    field :event_merets, :integer, default: 0
    field :game_merets, :integer, default: 0
    field :havi_fruits, :integer, default: 0
    field :merets, :integer, default: 100
    field :meso_tokens, :integer, default: 0
    field :mesos, :integer, default: 10_000
    field :rues, :integer, default: 0
    field :trevas, :integer, default: 0
    field :valor_tokens, :integer, default: 0
  end

  @doc false
  def changeset(wallet, attrs) do
    wallet
    |> cast(attrs, @fields)
    |> validate_required(@fields)
  end

  def currency_type(currency), do: Map.get(@types, currency)
end
