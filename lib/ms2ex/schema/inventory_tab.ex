defmodule Ms2ex.Schema.InventoryTab do
  use Ecto.Schema

  import Ecto.Changeset

  alias Ms2ex.Enums
  alias Ms2ex.Schema
  alias Ms2ex.Storage.Tables.Constants

  @type t :: %__MODULE__{}

  schema "inventory_tabs" do
    belongs_to :character, Schema.Character

    field :slots, :integer
    field :tab, Ms2ex.Enums.InventoryTab
  end

  @doc false
  def changeset(inventory_tab, attrs) do
    inventory_tab
    |> cast(attrs, [:slots, :tab])
    |> validate_required([:tab])
    |> ensure_slots()
  end

  defp ensure_slots(%{valid?: true} = inventory_tab) do
    if get_field(inventory_tab, :slots) do
      inventory_tab
    else
      tab = get_field(inventory_tab, :tab)
      slots = Map.get(default_slots(), tab)

      inventory_tab
      |> change(slots: slots)
      |> validate_required([:slots])
    end
  end

  defp ensure_slots(inventory_tab), do: inventory_tab

  def default_slots() do
    inventory_constants()
    |> Enum.into(%{}, fn {tab, {base, _max_expansion}} -> {tab, base} end)
  end

  def extra_slots(tab, slots) do
    diff = slots - Map.fetch!(default_slots(), tab)
    if diff < 0, do: 0, else: diff
  end

  def max_expansion(tab), do: elem(Map.fetch!(inventory_constants(), tab), 1)

  defp inventory_constants do
    Enum.into(Enums.InventoryTab.all(), %{}, fn tab ->
      {tab, constant_slots(tab)}
    end)
  end

  defp constant_slots(tab) do
    case Constants.get(constant_key(tab)) do
      value when is_binary(value) -> parse_slots(value)
      value when is_list(value) and length(value) >= 2 -> {Enum.at(value, 0), Enum.at(value, 1)}
      _ -> {fallback_slots(tab), fallback_expansion(tab)}
    end
  end

  defp parse_slots(value) do
    case String.split(value, ",", trim: true) |> Enum.map(&String.to_integer(String.trim(&1))) do
      [base, max_expansion | _] -> {base, max_expansion}
      _ -> {48, 0}
    end
  rescue
    ArgumentError -> {48, 0}
  end

  defp constant_key(:gear), do: :bag_slot_tab_game_count
  defp constant_key(:outfit), do: :bag_slot_tab_skin_count
  defp constant_key(:mount), do: :bag_slot_tab_summon_count
  defp constant_key(:catalyst), do: :bag_slot_tab_material_count
  defp constant_key(:fishing_music), do: :bag_slot_tab_life_count
  defp constant_key(:quest), do: :bag_slot_tab_quest_count
  defp constant_key(:gemstone), do: :bag_slot_tab_gem_count
  defp constant_key(:misc), do: :bag_slot_tab_misc_count
  defp constant_key(:life_skill), do: :bag_slot_tab_mastery_count
  defp constant_key(:pets), do: :bag_slot_tab_pet_count
  defp constant_key(:consumable), do: :bag_slot_tab_active_skill_count
  defp constant_key(:currency), do: :bag_slot_tab_coin_count
  defp constant_key(:badge), do: :bag_slot_tab_badge_count
  defp constant_key(:lapenshard), do: :bag_slot_tab_lapen_shard_count
  defp constant_key(:fragment), do: :bag_slot_tab_piece_count

  defp fallback_slots(:outfit), do: 156
  defp fallback_slots(:misc), do: 84
  defp fallback_slots(:life_skill), do: 126
  defp fallback_slots(:pets), do: 60
  defp fallback_slots(:consumable), do: 84
  defp fallback_slots(:badge), do: 60
  defp fallback_slots(_tab), do: 48

  defp fallback_expansion(_tab), do: 0
end
