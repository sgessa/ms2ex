defmodule Ms2ex.Schema.HotBar do
  use Ecto.Schema

  import Ecto.Changeset

  alias Ms2ex.{EctoTypes, Schema, Types}

  @type t :: %__MODULE__{}
  @max_slots 25
  @default_slots Enum.map(1..@max_slots, fn _ -> %Types.QuickSlot{} end)

  schema "hot_bars" do
    belongs_to :character, Schema.Character

    field :active, :boolean, default: false
    field :quick_slots, EctoTypes.Term, default: @default_slots
  end

  @doc false
  def changeset(hot_bar, attrs) do
    hot_bar
    |> cast(attrs, [:active, :quick_slots])
    |> validate_required([:active, :quick_slots])
  end

  def max_quick_slots(), do: @max_slots
end
