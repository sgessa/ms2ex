defmodule Ms2ex.InventorySlotsTest do
  use ExUnit.Case, async: true

  alias Ms2ex.Enums.InventoryTab, as: InventoryTabEnum
  alias Ms2ex.Schema.InventoryTab, as: InventoryTabSchema

  test "default inventory slots match the reference constants" do
    expected = %{
      gear: 48,
      outfit: 156,
      mount: 48,
      catalyst: 48,
      fishing_music: 48,
      quest: 48,
      gemstone: 48,
      misc: 84,
      life_skill: 126,
      pets: 60,
      consumable: 84,
      currency: 48,
      badge: 60,
      lapenshard: 48,
      fragment: 48
    }

    assert InventoryTabEnum.all() |> Map.new(&{&1, Map.fetch!(expected, &1)}) ==
             InventoryTabSchema.default_slots()
  end

  test "extra slot calculation preserves expansions above the reference base" do
    assert InventoryTabSchema.extra_slots(:misc, 90) == 6
    assert InventoryTabSchema.extra_slots(:outfit, 156) == 0
  end
end
