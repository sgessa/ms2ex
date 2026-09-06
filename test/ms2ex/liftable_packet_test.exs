defmodule Ms2ex.LiftablePacketTest do
  use Ms2ex.DataCase, async: true

  alias Ms2ex.Packets

  import Ms2ex.Packets.PacketReader

  @liftable %{
    uuid: "14c5a73cd3dd48609550 925d771003f1",
    count: 1,
    state: :default,
    mask_quest_id: "40002720,40002720",
    mask_quest_state: "1,1",
    effect_quest_id: "40002720",
    effect_quest_state: "1",
    react_effect: true
  }

  test "batch carries the react flag that drives the quest-effect glow" do
    bytes = Packets.Liftable.batch_update([@liftable])

    {opcode, packet} = get_short(bytes)
    {command, packet} = get_byte(packet)
    {count, packet} = get_int(packet)
    {uuid, packet} = get_string(packet)
    {one, packet} = get_byte(packet)
    {prop_count, packet} = get_int(packet)
    {state, packet} = get_byte(packet)
    {mask_quest_id, packet} = get_ustring(packet)
    {mask_quest_state, packet} = get_ustring(packet)
    {effect_quest_id, packet} = get_ustring(packet)
    {effect_quest_state, packet} = get_ustring(packet)
    {react_effect, packet} = get_bool(packet)

    assert {opcode, command, count} == {0x75, 0x0, 1}
    assert uuid == @liftable.uuid
    assert {one, prop_count, state} == {1, 1, 0}
    assert mask_quest_id == "40002720,40002720"
    assert mask_quest_state == "1,1"
    assert {effect_quest_id, effect_quest_state} == {"40002720", "1"}
    assert react_effect
    assert packet == <<>>
  end

  test "add carries the react flag for placed props" do
    bytes = Packets.Liftable.add(@liftable)

    {opcode, packet} = get_short(bytes)
    {command, packet} = get_byte(packet)
    {uuid, packet} = get_string(packet)
    {prop_count, packet} = get_int(packet)
    {mask_quest_id, packet} = get_ustring(packet)
    {mask_quest_state, packet} = get_ustring(packet)
    {effect_quest_id, packet} = get_ustring(packet)
    {effect_quest_state, packet} = get_ustring(packet)
    {react_effect, packet} = get_bool(packet)

    assert {opcode, command} == {0x75, 0x3}
    assert uuid == @liftable.uuid
    assert prop_count == 1
    assert mask_quest_id == "40002720,40002720"
    assert mask_quest_state == "1,1"
    assert {effect_quest_id, effect_quest_state} == {"40002720", "1"}
    assert react_effect
    assert packet == <<>>
  end
end
