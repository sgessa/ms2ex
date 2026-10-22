defmodule Ms2ex.InventoryPetItemPacketTest do
  use ExUnit.Case, async: true

  alias Ms2ex.Packets.InventoryItem
  alias Ms2ex.Schema
  alias Ms2ex.Types

  @pet_name "Miso"

  test "pet items write their info block where the template block would go" do
    item = %Schema.Item{
      id: 77,
      item_id: 6_000_001,
      amount: 1,
      rarity: 1,
      inventory_tab: :pets,
      inventory_slot: 3,
      inserted_at: ~U[2026-01-01 00:00:00Z],
      metadata: %{
        limit: %{level: 1, transfer_type: 3},
        property: %{type: 3},
        slot_names: [],
        option: %{constant_id: 0, pick_id: 0, static_id: 0, random_id: 0}
      },
      data: %{pet: %{name: @pet_name, exp: 300, evolve_points: 2, level: 4, rename_remaining: 0}},
      stats: %Types.ItemStats{}
    }

    character = %Schema.Character{id: 1, name: "Tester"}
    packet = InventoryItem.add_item({:create, item}, character)

    # ustring name + long exp + int evolve points + int level + bool has-items;
    # the block sits mid-packet (transfer flags, sockets and binding follow it)
    name_utf16 = :unicode.characters_to_binary(@pet_name, :utf8, {:utf16, :little})

    pet_block =
      <<byte_size(@pet_name)::little-16>> <>
        name_utf16 <>
        <<300::little-signed-64, 2::little-signed-32, 4::little-signed-32, 0>>

    assert packet =~ pet_block
  end

  test "items without pet state read through the defaults" do
    pet = Types.ItemPet.get(%Schema.Item{data: nil})

    assert pet == %Types.ItemPet{
             name: "",
             exp: 0,
             evolve_points: 0,
             level: 1,
             rename_remaining: 1
           }
  end
end
