defmodule Ms2ex.Inventory.Item do
  use Ecto.Schema

  alias Ms2ex.{EctoTypes, Metadata}

  import Ecto.Changeset
  import EctoEnum

  @fields [
    :amount,
    :color,
    :data,
    :equip_slot,
    :item_id,
    :inventory_slot,
    :inventory_tab,
    :location
  ]

  @required [:amount, :item_id, :location]
  @equip_slots Map.to_list(Metadata.EquipSlot.mapping())
  @inventory_tabs Map.to_list(Metadata.InventoryTab.mapping())

  defenum(EquipSlot, @equip_slots)
  defenum(InventoryTab, @inventory_tabs)
  defenum(Location, inventory: 0, equipment: 1)

  schema "inventory_items" do
    belongs_to :character, Ms2ex.Character

    field :item_id, :integer
    field :amount, :integer, default: 1

    field :color, EctoTypes.Term
    field :data, EctoTypes.Term
    field :equip_slot, EquipSlot, default: :NONE
    field :metadata, :map, virtual: true
    field :appearance_flag, :integer, virtual: true, default: 0
    field :can_repackage, :boolean, virtual: true, default: true
    field :charges, :integer, virtual: true, default: 0
    field :enchants, :integer, virtual: true, default: 0
    field :enchant_exp, :integer, virtual: true, default: 0
    field :expires_at, :utc_datetime, virtual: true
    field :glamor_forges_left, :integer, virtual: true, default: 0
    field :is_locked, :boolean, virtual: true, default: false
    field :inventory_slot, :integer, default: -1
    field :inventory_tab, InventoryTab
    field :location, Location, default: :inventory
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
