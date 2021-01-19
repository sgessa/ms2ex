defmodule Ms2ex.InventoryItems.Item do
  use Ecto.Schema

  alias Ms2ex.{EctoTypes, ItemColor, Color}

  import Ecto.Changeset
  import EctoEnum

  defenum(TabType,
    gear: 0,
    outfit: 1,
    mount: 2,
    catalyst: 3,
    fishing_music: 4,
    quest: 5,
    gemstone: 6,
    misc: 7,
    life_skill: 9,
    pets: 10,
    consumable: 11,
    currency: 12,
    badge: 13,
    lapen_shard: 15,
    fragment: 16
  )

  defenum(SlotType,
    none: 0,
    hair: 102,
    face: 103,
    face_decor: 104,
    ears: 105,
    fh: 110,
    ey: 111,
    ea: 112,
    cp: 113,
    top: 114,
    bottom: 115,
    gl: 116,
    shoes: 117,
    mt: 118,
    pd: 119,
    ri: 120,
    be: 121,
    rh: 1,
    lh: 2,
    oh: 3
  )

  defenum(SlotName,
    none: "NONE",
    hair: "HR",
    face: "FA",
    face_decor: "FD",
    top: "CL",
    bottom: "PA",
    shoes: "SH"
  )

  @fields [:amount, :color, :data, :is_template, :item_id, :slot_type, :max_slot, :tab_type]
  @required [:amount, :is_template, :item_id, :slot_type, :max_slot, :tab_type]

  schema "inventory_items" do
    belongs_to :character, Ms2ex.Users.Character

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

    # TODO read from metadata, remove from schema
    field :appearance_flag, :integer, virtual: true, default: 0
    field :can_repackage, :boolean, virtual: true, default: true
    field :charges, :integer, virtual: true, default: 0
    field :enchants, :integer, virtual: true, default: 0
    field :enchant_exp, :integer, virtual: true, default: 0
    field :expires_at, :utc_datetime, virtual: true
    field :glamor_forges_left, :integer, virtual: true, default: 0
    field :is_locked, :boolean, virtual: true, default: false
    field :is_template, :boolean, default: false
    field :max_slot, :integer, default: 100
    field :paired_character_id, :integer, virtual: true, default: 0
    field :paired_character_name, :integer, virtual: true, default: ""
    field :rarity, :integer, virtual: true, default: 0
    field :remaining_trades, :integer, virtual: true, default: 0
    field :slot, :integer, virtual: true, default: -1
    field :slot_type, SlotType
    field :tab_type, TabType, default: :outfit
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

  def slot_name(slot_type) do
    Keyword.get(SlotName.__enum_map__(), slot_type)
  end
end
