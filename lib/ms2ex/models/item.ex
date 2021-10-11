defmodule Ms2ex.Item do
  use Ecto.Schema

  alias Ms2ex.{EctoTypes, Metadata}

  import Ecto.Changeset
  import EctoEnum

  @fields [
    :amount,
    :basic_attributes,
    :bonus_attributes,
    :color,
    :data,
    :enchants,
    :equip_slot,
    :item_id,
    :inventory_slot,
    :inventory_tab,
    :location,
    :rarity,
    :transfer_flags
  ]

  @required [:amount, :item_id, :location]
  @equip_slots Map.to_list(Metadata.EquipSlot.mapping())
  @inventory_tabs Map.to_list(Metadata.InventoryTab.mapping())

  defenum(EquipSlot, @equip_slots)
  defenum(Location, inventory: 0, equipment: 1)
  defenum(TabType, @inventory_tabs)

  schema "inventory_items" do
    belongs_to :character, Ms2ex.Character

    field :item_id, :integer
    field :amount, :integer, default: 1

    field :basic_attributes, EctoTypes.Term
    field :bonus_attributes, EctoTypes.Term
    field :color, EctoTypes.Term
    field :data, EctoTypes.Term
    field :equip_slot, EquipSlot, default: :NONE
    field :metadata, :map, virtual: true
    field :appearance_flag, :integer, virtual: true, default: 0
    field :can_repackage, :boolean, virtual: true, default: true
    field :charges, :integer, virtual: true, default: 0
    field :enchants, :integer, default: 0
    field :enchant_exp, :integer, virtual: true, default: 0
    field :expires_at, :utc_datetime, virtual: true
    field :glamor_forges_left, :integer, virtual: true, default: 0
    field :is_locked, :boolean, virtual: true, default: false
    field :inventory_slot, :integer
    field :inventory_tab, TabType
    field :location, Location, default: :inventory
    field :lock_character_id, :integer, virtual: true
    field :mob_drop?, :boolean, virtual: true, default: false
    field :object_id, :integer, virtual: true
    field :paired_character_id, :integer, virtual: true, default: 0
    field :paired_character_name, :string, virtual: true, default: ""
    field :position, EctoTypes.Term, virtual: true
    field :rarity, :integer
    field :remaining_trades, :integer, virtual: true, default: 0
    field :source_object_id, :integer, virtual: true
    field :target_object_id, :integer, virtual: true
    field :times_attr_changed, :integer, virtual: true, default: 0
    field :transfer_flags, :integer, default: 0
    field :unlocks_at, :utc_datetime, virtual: true

    timestamps(type: :utc_datetime)
  end

  def changeset(item, attrs) do
    item
    |> cast(attrs, @fields)
    |> validate_required(@required)
  end
end
