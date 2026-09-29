defmodule Ms2ex.SkillDamageTargetTest do
  use Ms2ex.DataCase, async: true

  alias Ms2ex.Packets
  alias Ms2ex.Types

  import Ms2ex.Packets.PacketReader

  @caster %Ms2ex.Schema.Character{id: 1, object_id: 10_000_001, name: "Testy"}

  defp skill_cast do
    %Types.SkillCast{
      id: 1_234,
      caster: @caster,
      skill_id: 99_900_241,
      skill_level: 1,
      motion_point: 0,
      attack_point: 0,
      server_tick: 21_373,
      position: %Types.Coord{x: -176.28, y: 2178.85, z: 1352.0},
      direction: %Types.Coord{x: 0.694, y: -0.719, z: 0.0}
    }
  end

  test "target relay carries the caster, aim and the reported hit chain" do
    records = [
      %{prev_uid: 0, uid: 7, target_id: 54, unknown: 0, index: 0},
      %{prev_uid: 7, uid: 8, target_id: 55, unknown: 1, index: 1}
    ]

    bytes = Packets.SkillDamage.target(skill_cast(), records)

    {opcode, packet} = get_short(bytes)
    {mode, packet} = get_byte(packet)
    {cast_id, packet} = get_long(packet)
    {caster_id, packet} = get_int(packet)
    {skill_id, packet} = get_int(packet)
    {skill_level, packet} = get_short(packet)
    {motion_point, packet} = get_byte(packet)
    {attack_point, packet} = get_byte(packet)

    # the impact position rides short coords, the direction full floats
    {x, packet} = get_short(packet)
    {y, packet} = get_short(packet)
    {z, packet} = get_short(packet)
    {dir_x, packet} = get_float(packet)
    {dir_y, packet} = get_float(packet)
    {dir_z, packet} = get_float(packet)
    {always_true, packet} = get_bool(packet)
    {server_tick, packet} = get_int(packet)
    {count, packet} = get_byte(packet)

    assert opcode == 0x3E
    assert mode == 0x0
    assert cast_id == 1_234
    assert caster_id == 10_000_001
    assert skill_id == 99_900_241
    assert skill_level == 1
    assert motion_point == 0
    assert attack_point == 0
    assert {x, y, z} == {-176, 2179, 1352}
    assert_in_delta dir_x, 0.694, 0.001
    assert_in_delta dir_y, -0.719, 0.001
    assert dir_z == 0.0
    assert always_true
    assert server_tick == 21_373
    assert count == 2

    {lead_prev, packet} = get_long(packet)
    assert lead_prev == 0
    {first, packet} = get_long(packet)
    assert first == 7
    {first_target, packet} = get_int(packet)
    assert first_target == 54
    {first_unknown, packet} = get_byte(packet)
    assert first_unknown == 0
    {first_index, packet} = get_byte(packet)
    assert first_index == 0
    {prev_uid, packet} = get_long(packet)
    assert prev_uid == 7
    {second, packet} = get_long(packet)
    assert second == 8
    {second_target, packet} = get_int(packet)
    {second_unknown, packet} = get_byte(packet)
    assert second_unknown == 1
    {second_index, packet} = get_byte(packet)
    assert second_index == 1

    assert packet == <<>>
  end
end
