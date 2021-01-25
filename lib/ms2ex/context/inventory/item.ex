defmodule Ms2ex.Inventory.Item do
  use Ecto.Schema

  alias Ms2ex.{EctoTypes, ItemColor, Color}

  import Ecto.Changeset

  @fields [:amount, :color, :data, :item_id]
  @required [:amount, :item_id]

  schema "inventory_items" do
    belongs_to :character, Ms2ex.Character

    field :item_id, :integer
    field :amount, :integer, default: 1

    field :color, EctoTypes.Term,
      default:
        ItemColor.build(
          Color.build(0, 0, 0, -1),
          Color.build(0, 0, 0, -1),
          Color.build(0, 0, 0, -1),
          0
        )

    field :data, EctoTypes.Term
    field :metadata, :map, virtual: true
    field :appearance_flag, :integer, virtual: true, default: 0
    field :can_repackage, :boolean, virtual: true, default: true
    field :charges, :integer, virtual: true, default: 0
    field :enchants, :integer, virtual: true, default: 0
    field :enchant_exp, :integer, virtual: true, default: 0
    field :expires_at, :utc_datetime, virtual: true
    field :glamor_forges_left, :integer, virtual: true, default: 0
    field :is_locked, :boolean, virtual: true, default: false
    field :paired_character_id, :integer, virtual: true, default: 0
    field :paired_character_name, :integer, virtual: true, default: ""
    field :remaining_trades, :integer, virtual: true, default: 0
    field :times_attr_changed, :integer, virtual: true, default: 0
    field :transfer_flag, :integer, virtual: true, default: 0
    field :unlocks_at, :utc_datetime, virtual: true

    timestamps(type: :utc_datetime)
  end

  def changeset(item, attrs) do
    item
    |> cast(attrs, @fields)
    |> validate_required(@required)
  end
end
