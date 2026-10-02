defmodule Ms2ex.ShopPacketTest do
  use ExUnit.Case, async: true

  # every shop packet rides opcode 0x52
  @opcode <<0x52::little-16>>

  describe "npc talk responses around vendors" do
    @npc_talk <<0x4C::little-16>>

    @greeting_state %{type: :select, id: 0, contents: [%{button_type: 0, distractors: []}]}

    test "a vendor greeting answers with the dialog flag and no button" do
      # talk_type dialog (0x01), kind 13 (shop): the client closes the
      # dialogue and reveals the shop window
      assert Ms2ex.Packets.NpcTalk.respond(5, 0x01, @greeting_state, 13) ==
               <<@npc_talk, 0x01, 5::little-32, 0x01, 0::little-32, 0::little-32, 0::little-32>>
    end

    test "the choice menu keeps the selectable talk button" do
      assert Ms2ex.Packets.NpcTalk.respond(5, 0x0E, @greeting_state, nil) ==
               <<@npc_talk, 0x01, 5::little-32, 0x0E, 0::little-32, 0::little-32, 5::little-32>>
    end

    test "picking the dialog option on a vendor closes into the shop" do
      assert Ms2ex.Packets.NpcTalk.continue(0x02, 0, nil) ==
               <<@npc_talk, 0x02, 0x02, 0::little-32, 0::little-32, 0::little-32, 0::little-32>>
    end
  end

  test "error writes the command, error value and args" do
    assert Ms2ex.Packets.Shop.error(:lack_meso) ==
             <<@opcode, 0x0F, 10::little-32, 0, 0::little-32>>
  end

  test "update writes the purchased stock of an entry" do
    assert Ms2ex.Packets.Shop.update(7, 3) ==
             <<@opcode, 0x02, 7::little-32, 3::little-32>>
  end

  test "buy echoes the bought item" do
    packet = Ms2ex.Packets.Shop.buy(5_000_001, 3, 750, 2)

    assert packet == <<@opcode, 0x04, 5_000_001::little-32, 3::little-32, 750::little-32, 2, 0>>
  end

  test "buy back bookkeeping packets" do
    assert Ms2ex.Packets.Shop.buy_back_item_count(2) == <<@opcode, 0x06, 2::little-16>>
    assert Ms2ex.Packets.Shop.remove_buy_back(4) == <<@opcode, 0x08, 4::little-32>>
    assert Ms2ex.Packets.Shop.instant_restock() == <<@opcode, 0x09, 0>>
  end
end
