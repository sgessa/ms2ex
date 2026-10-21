defmodule Ms2ex.ResponsePetPacketTest do
  use ExUnit.Case, async: true

  alias Ms2ex.Packets
  alias Ms2ex.Schema
  alias Ms2ex.Types

  @pet_item_id 6_000_001

  defp field_pet do
    metadata = %{
      basic: %{level: 10},
      stat: %{stats: %{}}
    }

    item = %Schema.Item{
      id: 55,
      item_id: @pet_item_id,
      amount: 1,
      rarity: 2,
      inventory_tab: :pets,
      inventory_slot: 0,
      inserted_at: ~U[2026-01-01 00:00:00Z],
      metadata: %{
        limit: %{level: 1, transfer_type: 3},
        property: %{type: 3},
        slot_names: [],
        option: %{constant_id: 0, pick_id: 0, static_id: 0, random_id: 0}
      },
      data: %{pet: %{name: "Miso", exp: 300, evolve_points: 2, level: 4, rename_remaining: 1}},
      stats: %Types.ItemStats{}
    }

    Types.FieldPet.new(
      object_id: 9,
      item: item,
      npc: Types.Npc.new(%{id: 60_000_001, metadata: metadata}),
      pet: %{npc_id: 60_000_001},
      owner_character_id: 1,
      owner_object_id: 7,
      position: %{x: 1.0, y: 2.0, z: 3.0},
      rotation: %{x: 0.0, y: 0.0, z: 0.0},
      skin_id: 60_000_001
    )
  end

  test "summon names the owner, pet object and item" do
    decoded =
      Packets.Decoder.decode(
        :send,
        Packets.ResponsePet.summon(field_pet(), %Schema.Character{id: 1, name: "Tester"})
      )

    assert decoded.name == "RESPONSE_PET"
    assert decoded.command == :summon
    assert decoded.fields.owner_object_id == 7
    assert decoded.fields.pet_object_id == 9
    assert decoded.fields.item_id == @pet_item_id
    assert decoded.fields.item_uid == 55
    assert decoded.fields.rarity == 2
    # the item body block has no layout; it follows the decoded head
    assert byte_size(decoded.rest) > 0
  end

  test "load carries the pet profile and default config" do
    item = field_pet().item

    decoded =
      Packets.Decoder.decode(:send, Packets.ResponsePet.load(7, item, Types.PetConfig.new()))

    assert decoded.command == :load
    assert decoded.fields.owner_object_id == 7
    assert decoded.fields.name == "Miso"
    assert decoded.fields.exp == 300
    assert decoded.fields.level == 4
    assert decoded.fields.rename_remaining == 1
    assert decoded.fields.potion_count == 0
    assert decoded.rest == <<>>
  end

  test "un_summon names the owner and the pet item uid" do
    decoded = Packets.Decoder.decode(:send, Packets.ResponsePet.un_summon(7, 55))

    assert decoded.command == :un_summon
    assert decoded.fields == %{owner_object_id: 7, item_uid: 55}
    assert decoded.rest == <<>>
  end

  test "field add pet serializes the actor and its stats" do
    decoded = Packets.Decoder.decode(:send, Packets.FieldAddPet.add_pet(field_pet()))

    assert decoded.name == "FIELD_ADD_PET"
    # no spec yet: the packet decodes to the opcode head only
    assert decoded.rest != <<>>
  end
end
