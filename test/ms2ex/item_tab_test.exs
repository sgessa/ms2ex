defmodule Ms2ex.ItemTabTest do
  use ExUnit.Case, async: true

  alias Ms2ex.Types.Item

  test "consumables map to the consumable tab" do
    assert Item.inventory_tab(%{property: %{type: 2, subtype: 2}}) == :consumable
    assert Item.inventory_tab(%{property: %{type: 0, subtype: 2}}) == :consumable
    assert Item.inventory_tab(%{property: %{type: 18}}) == :consumable
  end

  test "type 1 distinguishes gear from outfits by skin flag" do
    assert Item.inventory_tab(%{property: %{type: 1, is_skin: false}}) == :gear
    assert Item.inventory_tab(%{property: %{type: 1, is_skin: true}}) == :outfit
  end

  test "fragment flag wins over the type" do
    assert Item.inventory_tab(%{property: %{type: 1, is_fragment: true}}) == :fragment
  end

  test "non-consumable subtypes of mixed types fall back to misc" do
    assert Item.inventory_tab(%{property: %{type: 2, subtype: 1}}) == :misc
    assert Item.inventory_tab(%{property: %{type: 0, subtype: 1}}) == :misc
  end

  test "various types map to their tabs" do
    assert Item.inventory_tab(%{property: %{type: 3}}) == :quest
    assert Item.inventory_tab(%{property: %{type: 9}}) == :mount
    assert Item.inventory_tab(%{property: %{type: 15}}) == :catalyst
    assert Item.inventory_tab(%{property: %{type: 20}}) == :currency
    assert Item.inventory_tab(%{property: %{type: 21}}) == :lapenshard
    assert Item.inventory_tab(%{property: %{type: 99}}) == :misc
  end
end
