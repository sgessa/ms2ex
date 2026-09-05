defmodule Ms2ex.MasteryTest do
  use ExUnit.Case, async: true

  alias Ms2ex.Formulas
  alias Ms2ex.Packets

  import Ms2ex.Packets.PacketReader

  describe "gathering success rate" do
    test "is guaranteed below the high rate limit" do
      assert Formulas.Gathering.success_rate(0, 10, 20) == 100.0
      assert Formulas.Gathering.success_rate(9, 10, 20) == 100.0
    end

    test "falls off past the high rate limit and never goes negative" do
      first = Formulas.Gathering.success_rate(11, 10, 20)
      later = Formulas.Gathering.success_rate(20, 10, 20)

      assert first < 100.0
      assert later < first
      assert Formulas.Gathering.success_rate(10_000, 10, 20) == 0.0
    end

    test "someone else's home cuts both limits to a fifth" do
      assert Formulas.Gathering.success_rate(5, 10, 20, false) <
               Formulas.Gathering.success_rate(5, 10, 20, true)
    end
  end

  describe "mastery packets" do
    test "update carries the type byte and the new value" do
      {opcode, packet} = Packets.Mastery.update_mastery(:mining, 1234) |> get_short()
      {command, packet} = get_byte(packet)
      {type, packet} = get_byte(packet)
      {value, packet} = get_int(packet)
      {_unknown, packet} = get_int(packet)

      assert {opcode, command, type, value, packet} == {0xCF, 0x00, 3, 1234, <<>>}
    end

    test "crafted items are listed with id and rarity" do
      items = [%{item_id: 4000, rarity: 2}]

      {opcode, packet} = Packets.Mastery.get_crafted_item(:cooking, items) |> get_short()
      {command, packet} = get_byte(packet)
      {type, packet} = get_short(packet)
      {count, packet} = get_int(packet)
      {item_id, packet} = get_int(packet)
      {rarity, packet} = get_short(packet)

      assert {opcode, command, type, count, item_id, rarity, packet} ==
               {0xCF, 0x02, 10, 1, 4000, 2, <<>>}
    end

    test "errors carry the short error code" do
      {opcode, packet} = Packets.Mastery.error(:s_mastery_error_lack_meso) |> get_short()
      {command, packet} = get_byte(packet)
      {error, packet} = get_short(packet)

      assert {opcode, command, error, packet} == {0xCF, 0x03, 2, <<>>}
    end
  end

  describe "interact object load" do
    test "only gathering objects carry the remaining gather count" do
      objects = [
        %{uuid: "a", state: :reactable, type: :mesh},
        %{uuid: "b", state: :reactable, type: :gathering}
      ]

      {opcode, packet} = Packets.InteractObject.load(objects) |> get_short()
      {command, packet} = get_byte(packet)
      {count, packet} = get_int(packet)

      {uuid_a, packet} = get_string(packet)
      {state_a, packet} = get_byte(packet)
      {type_a, packet} = get_byte(packet)

      {uuid_b, packet} = get_string(packet)
      {state_b, packet} = get_byte(packet)
      {type_b, packet} = get_byte(packet)
      {gather_count, packet} = get_int(packet)

      assert {opcode, command, count} == {0x65, 0x08, 2}
      assert {uuid_a, state_a, type_a} == {"a", 1, 1}
      assert {uuid_b, state_b, type_b} == {"b", 1, 6}
      assert {gather_count, packet} == {10, <<>>}
    end

    test "every interact type maps to its client byte" do
      types = [
        {:mesh, 1},
        {:telescope, 2},
        {:ui, 3},
        {:web, 4},
        {:display_image, 5},
        {:gathering, 6},
        {:guild_poster, 7},
        {:bill_board, 8},
        {:watch_tower, 9}
      ]

      for {type, expected} <- types do
        {_opcode, packet} =
          Packets.InteractObject.update(%{uuid: "x", state: :normal, type: type}) |> get_short()

        {_command, packet} = get_byte(packet)
        {_uuid, packet} = get_string(packet)
        {_state, packet} = get_byte(packet)
        {byte, _packet} = get_byte(packet)

        assert byte == expected, "#{type} should serialize as #{expected}"
      end
    end
  end

  describe "user env load packets" do
    test "gathering counts serialize as recipe/count pairs" do
      {opcode, packet} = Packets.UserEnv.gathering_counts(%{5 => 3}) |> get_short()
      {command, packet} = get_byte(packet)
      {count, packet} = get_int(packet)
      {recipe_id, packet} = get_int(packet)
      {harvests, packet} = get_int(packet)
      {_trailing, packet} = get_int(packet)

      assert {opcode, command, count, recipe_id, harvests, packet} ==
               {0xAA, 0x08, 1, 5, 3, <<>>}
    end

    test "claimed mastery rewards serialize as id/flag pairs" do
      {opcode, packet} = Packets.UserEnv.mastery_rewards_claimed(%{3001 => true}) |> get_short()
      {command, packet} = get_byte(packet)
      {count, packet} = get_int(packet)
      {reward_box_id, packet} = get_int(packet)
      {claimed, packet} = get_byte(packet)

      assert {opcode, command, count, reward_box_id, claimed, packet} ==
               {0xAA, 0x09, 1, 3001, 1, <<>>}
    end
  end
end
