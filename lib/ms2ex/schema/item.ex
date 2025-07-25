defmodule Ms2ex.Schema.Item do
  use Ecto.Schema

  alias Ms2ex.{EctoTypes, Enums, Schema}

  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @fields [
    :amount,
    :color,
    :data,
    :enchant_level,
    :equip_slot,
    :item_id,
    :inventory_slot,
    :inventory_tab,
    :limit_break_level,
    :location,
    :rarity,
    :stats,
    :transfer_flags
  ]

  @required [:amount, :item_id, :location]

  schema "inventory_items" do
    belongs_to :character, Schema.Character

    field :item_id, :integer
    field :amount, :integer, default: 1

    field :color, EctoTypes.Term
    field :data, EctoTypes.Term
    field :equip_slot, Enums.EquipSlot, default: :NONE
    field :metadata, :map, virtual: true
    field :appearance_flag, :integer, virtual: true, default: 0
    field :can_repackage, :boolean, virtual: true, default: true
    field :charges, :integer, virtual: true, default: 0
    field :enchant_exp, :integer, virtual: true, default: 0
    field :enchant_level, :integer, default: 0
    field :expires_at, :utc_datetime, virtual: true
    field :glamor_forges_left, :integer, virtual: true, default: 0
    field :is_locked, :boolean, virtual: true, default: false
    field :inventory_slot, :integer
    field :inventory_tab, Enums.InventoryTab
    field :limit_break_level, :integer, default: 0
    field :location, Ecto.Enum, values: [inventory: 0, equipment: 1], default: :inventory
    field :lock_character_id, :integer, virtual: true
    field :mob_drop?, :boolean, virtual: true, default: false
    field :object_id, :integer, virtual: true
    field :paired_character_id, :integer, virtual: true, default: 0
    field :paired_character_name, :string, virtual: true, default: ""
    field :position, EctoTypes.Term, virtual: true
    field :rarity, :integer
    field :remaining_trades, :integer, virtual: true, default: 0
    field :source_object_id, :integer, virtual: true
    field :stats, EctoTypes.Term
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
