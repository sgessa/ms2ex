defmodule Ms2ex.SkillDamagePacketTest do
  use Ms2ex.DataCase, async: true

  alias Ms2ex.Packets
  alias Ms2ex.Types.Coord

  import Ms2ex.Packets.PacketReader

  @hit %{
    caster_object_id: 77,
    target_object_id: 900,
    skill_id: 50_000_323,
    skill_level: 1,
    position: %Coord{x: 100.0, y: 200.0, z: 300.0},
    direction: %Coord{x: 0.0, y: 1.0, z: 0.0},
    server_tick: 123_456,
    attack_counter: 3
  }

  test "the target record carries the caster, skill and homing target" do
    bytes = Packets.SkillDamage.target(@hit, 0, 900)

    {_opcode, packet} = get_short(bytes)
    {mode, packet} = get_byte(packet)
    {cast_uid, packet} = get_long(packet)
    {caster_id, packet} = get_int(packet)
    {skill_id, packet} = get_int(packet)
    {skill_level, packet} = get_short(packet)
    {motion_point, packet} = get_byte(packet)
    {attack_point, packet} = get_byte(packet)
    {position, packet} = get_short_coord(packet)
    {direction, packet} = get_coord(packet)
    {animate, packet} = get_bool(packet)
    {server_tick, packet} = get_int(packet)
    {target_count, packet} = get_byte(packet)
    {prev_uid, packet} = get_long(packet)
    {uid, packet} = get_long(packet)
    {target_id, packet} = get_int(packet)
    {unknown, packet} = get_byte(packet)
    {index, _packet} = get_byte(packet)

    assert mode == 0
    assert cast_uid == 0
    assert caster_id == 77
    assert skill_id == 50_000_323
    assert skill_level == 1
    assert motion_point == 0
    assert attack_point == 0
    assert %Coord{x: 100, y: 200, z: 300} = position
    assert %Coord{x: +0.0, y: 1.0, z: +0.0} = direction
    assert animate
    assert server_tick == 123_456
    assert target_count == 1
    assert prev_uid == 0
    # synthetic per-segment uid (2 + segment index)
    assert uid == 2
    assert target_id == 900
    assert unknown == 0
    assert index == 0
  end

  test "a region hit's target record chains uids from the region source id" do
    splash_cast = %{
      caster: %{object_id: 9001},
      skill_id: 10_100_101,
      skill_level: 4,
      position: %{x: 100, y: -50, z: 200},
      direction: nil
    }

    mobs = [
      {%{object_id: 51, position: %{x: 110, y: -40, z: 200}}, %{crit?: false, dmg: 42}},
      {%{object_id: 52, position: %{x: 90, y: -60, z: 200}}, %{crit?: true, dmg: 60}}
    ]

    bytes = Packets.SkillDamage.region_target(splash_cast, 7_000, mobs, 1234)

    {_opcode, packet} = get_short(bytes)
    {mode, packet} = get_byte(packet)
    {cast_uid, packet} = get_long(packet)
    {caster_id, packet} = get_int(packet)
    {skill_id, packet} = get_int(packet)
    {_level, packet} = get_short(packet)
    {_motion, packet} = get_byte(packet)
    {_attack, packet} = get_byte(packet)
    {_position, packet} = get_short_coord(packet)
    {_direction, packet} = get_coord(packet)
    {_animate, packet} = get_bool(packet)
    {_tick, packet} = get_int(packet)
    {count, packet} = get_byte(packet)

    {uid1, packet} = parse_target(packet)
    {uid2, _packet} = parse_target(packet)

    assert mode == 0x0
    assert cast_uid == 0
    assert caster_id == 9001
    assert skill_id == 10_100_101
    assert count == 2
    assert uid1 == 7_000 * 0x1_0000_0000 + 0
    assert uid2 == 7_000 * 0x1_0000_0000 + 1
  end

  test "a region damage record keys the caster and owner on the source id" do
    splash_cast = %{
      caster: %{object_id: 9001},
      skill_id: 10_100_101,
      skill_level: 4,
      position: %{x: 100, y: -50, z: 200}
    }

    mobs = [
      {%{object_id: 51, position: %{x: 110, y: -40, z: 200}},
       %{crit?: false, dmg: 42, direction: %{x: 1.0, y: 0.0, z: 0.0}}}
    ]

    bytes = Packets.SkillDamage.region(splash_cast, 7_000, mobs)

    {_opcode, packet} = get_short(bytes)
    {mode, packet} = get_byte(packet)
    {skill_uid, packet} = get_long(packet)
    {caster_id, packet} = get_int(packet)
    {owner_id, packet} = get_int(packet)
    {_attack_point, packet} = get_byte(packet)
    {count, packet} = get_byte(packet)
    {target_id, packet} = get_int(packet)
    {damage_count, packet} = get_byte(packet)
    {_position, packet} = get_short_coord(packet)
    {_direction, packet} = get_coord(packet)
    {type, packet} = get_byte(packet)
    {amount, _packet} = get_long(packet)

    assert mode == 0x5
    assert skill_uid == 0
    assert caster_id == 7_000
    assert owner_id == 7_000
    assert count == 1
    assert target_id == 51
    assert damage_count == 1
    assert type == 0
    assert amount == 42
  end

  defp parse_target(packet) do
    {_prev_uid, packet} = get_long(packet)
    {uid, packet} = get_long(packet)
    {_target_id, packet} = get_int(packet)
    {_unknown, packet} = get_byte(packet)
    {_index, packet} = get_byte(packet)
    {uid, packet}
  end

  test "a non-homing projectile carries a zero target id and indexes segments" do
    bytes = Packets.SkillDamage.target(@hit, 2, 0)

    {_opcode, packet} = get_short(bytes)
    {_mode, packet} = get_byte(packet)
    {_cast_uid, packet} = get_long(packet)
    {_caster_id, packet} = get_int(packet)
    {_skill_id, packet} = get_int(packet)
    {_skill_level, packet} = get_short(packet)
    {_motion_point, packet} = get_byte(packet)
    {_attack_point, packet} = get_byte(packet)
    {_position, packet} = get_short_coord(packet)
    {_direction, packet} = get_coord(packet)
    {_animate, packet} = get_bool(packet)
    {_server_tick, packet} = get_int(packet)
    {_target_count, packet} = get_byte(packet)
    {_prev_uid, packet} = get_long(packet)
    {uid, packet} = get_long(packet)
    {target_id, _packet} = get_int(packet)

    assert uid == 4
    assert target_id == 0
  end
end
