defmodule Ms2ex.Schema.InventoryTab do
  use Ecto.Schema

  import Ecto.Changeset

  alias Ms2ex.{Enums, Schema}

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
    Enums.InventoryTab.all()
    |> Enum.into(%{}, &{&1, 48})
    |> Map.put(:outfit, 150)
    |> Map.put(:life_skill, 126)
    |> Map.put(:pets, 60)
    |> Map.put(:consumable, 84)
    |> Map.put(:badge, 60)
  end

  def extra_slots(tab, slots) do
    default_slots = Map.get(default_slots(), tab)
    diff = slots - default_slots
    if diff < 0, do: 0, else: diff
  end
end
