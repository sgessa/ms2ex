defmodule Ms2ex.Packets.InventoryItemTest do
  use ExUnit.Case, async: true

  alias Ms2ex.Packets.InventoryItem
  alias Ms2ex.Packets.PacketWriter
  alias Ms2ex.Schema
  alias Ms2ex.Types

  test "serializes UGC item blueprint details" do
    item = %Schema.Item{
      id: 1,
      item_id: 11_050_001,
      amount: 1,
      inventory_slot: 0,
      rarity: 1,
      inserted_at: DateTime.from_unix!(1_700_000_000),
      metadata: %{mesh: "design", property: %{type: 0}},
      stats: %Types.ItemStats{},
      ugc: %{
        id: 100,
        account_id: 11,
        character_id: 12,
        author: "Maker",
        name: "Blueprint",
        created_at: 1_700_000_000,
        url: "blueprint/ms2/01/100/100.png",
        blueprint: %{
          uid: 101,
          length: 2,
          width: 3,
          height: 4,
          created_at: 1_700_000_001,
          type: :original,
          account_id: 11,
          character_id: 12,
          character_name: "Maker"
        }
      }
    }

    blueprint =
      <<>>
      |> PacketWriter.put_long(101)
      |> PacketWriter.put_int(2)
      |> PacketWriter.put_int(3)
      |> PacketWriter.put_int(4)
      |> PacketWriter.put_long(1_700_000_001)
      |> PacketWriter.put_int(1)
      |> PacketWriter.put_long(11)
      |> PacketWriter.put_long(12)
      |> PacketWriter.put_ustring("Maker")

    packet = InventoryItem.add_item({:create, item}, %Schema.Character{id: 12, name: "Maker"})

    assert :binary.match(packet, blueprint) != :nomatch
  end
end
