defmodule Ms2ex.NpcTalkPacketTest do
  use Ms2ex.DataCase, async: true

  alias Ms2ex.Packets

  import Ms2ex.Packets.PacketReader

  @npc_object_id 50_000_001

  test "respond serializes the talk choice menu for a select state" do
    state = %{type: :select, id: 0, contents: [%{text: "pick one"}]}

    bytes = Packets.NpcTalk.respond(@npc_object_id, 0x0E, state)

    {opcode, packet} = get_short(bytes)
    {command, packet} = get_byte(packet)
    {object_id, packet} = get_int(packet)
    {talk_type, packet} = get_byte(packet)
    {state_id, packet} = get_int(packet)
    {index, packet} = get_int(packet)
    {button, packet} = get_int(packet)

    assert {opcode, command} == {0x4C, 0x1}
    assert object_id == @npc_object_id
    # Quest | Talk | Select flags together
    assert talk_type == 0x0E
    assert {state_id, index} == {0, 0}
    # SelectableTalk renders the menu options
    assert button == 0x5
    assert packet == <<>>
  end

  test "respond keeps the quest band button on quest states" do
    state = %{type: :quest, id: 100, contents: [%{text: "accept?"}]}

    bytes = Packets.NpcTalk.respond(@npc_object_id, 0x04, state)

    {opcode, packet} = get_short(bytes)
    {command, packet} = get_byte(packet)
    {object_id, packet} = get_int(packet)
    {talk_type, packet} = get_byte(packet)
    {state_id, packet} = get_int(packet)
    {index, packet} = get_int(packet)
    {button, packet} = get_int(packet)

    assert {opcode, command} == {0x4C, 0x1}
    assert object_id == @npc_object_id
    assert talk_type == 0x04
    assert state_id == 100
    assert index == 0
    # the 100s accept band shows Accept/Decline
    assert button == 0x6
    assert packet == <<>>
  end
end
