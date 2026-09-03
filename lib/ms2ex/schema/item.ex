defmodule Ms2ex.Schema.Item do
  use Ecto.Schema

  alias Ms2ex.EctoTypes
  alias Ms2ex.Enums
  alias Ms2ex.Schema

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
    :is_bound,
    :is_locked,
    :limit_break_level,
    :location,
    :rarity,
    :remaining_trades,
    :stats,
    :transfer_flags,
    :unlocks_at,
    :ugc
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
    field :is_locked, :boolean, default: false
    field :inventory_slot, :integer
    field :inventory_tab, Enums.InventoryTab
    field :is_bound, :boolean, default: false
    field :level, :integer, virtual: true
    field :limit_break_level, :integer, default: 0
    field :location, Ecto.Enum, values: [inventory: 0, equipment: 1], default: :inventory
    field :lock_character_id, :integer, virtual: true
    field :mob_drop?, :boolean, virtual: true, default: false
    field :object_id, :integer, virtual: true
    field :position, EctoTypes.Term, virtual: true
    field :rarity, :integer
    field :remaining_trades, :integer, default: 0
    field :source_object_id, :integer, virtual: true
    field :stats, EctoTypes.Term
    field :target_object_id, :integer, virtual: true
    field :times_attr_changed, :integer, virtual: true, default: 0
    field :transfer_flags, EctoTypes.TransferFlags, default: []
    field :ugc, EctoTypes.Term
    field :unlocks_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  def changeset(item, attrs) do
    item
    |> cast(attrs, @fields)
    |> validate_required(@required)
  end

  @doc """
  Returns a changeset carrying the bind change (or the item unchanged) when
  the transfer type requires binding. Callers merge the changeset into the
  persist; the change is only produced when the item is not already bound.
  """
  @spec bind_if_needed(Schema.Item.t(), :loot | :equip) :: Schema.Item.t() | Ecto.Changeset.t()
  def bind_if_needed(%Schema.Item{} = item, on \\ :loot) do
    transfer_type = get_in(item.metadata, [:limit, :transfer_type]) || :tradeable

    binds? =
      case on do
        :loot -> transfer_type == :bind_on_loot
        :equip -> transfer_type in [:bind_on_loot, :bind_on_equip]
      end

    if binds? && bind_flagged?(item.transfer_flags) do
      change(item, is_bound: true, remaining_trades: 0)
    else
      item
    end
  end

  defp bind_flagged?(flags), do: :bind in flags
end
