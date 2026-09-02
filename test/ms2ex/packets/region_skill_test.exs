defmodule Ms2ex.Packets.RegionSkillTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Ms2ex.Packets.RegionSkill
  alias Ms2ex.Types.Coord
  alias Ms2ex.Types.SkillCast

  import Ms2ex.Packets.PacketReader
  import Ms2ex.TestHelpers

  setup do
    stub_metadata(%{"table:magicpath.xml" => %{table: %{entries: %{}}}})
    :ok
  end

  test "keeps rotation for directional region skills" do
    packet = RegionSkill.add(321, skill_cast(true, 45.0))
    {_opcode, packet} = get_short(packet)
    {mode, packet} = get_byte(packet)
    {_source_id, packet} = get_int(packet)
    {_source_id2, packet} = get_int(packet)
    {_next_tick, packet} = get_int(packet)
    {point_count, packet} = get_byte(packet)
    {_point, packet} = get_coord(packet)
    {_skill_id, packet} = get_int(packet)
    {_skill_level, packet} = get_short(packet)
    {rotation_h, packet} = get_float(packet)
    {rotation_v, packet} = get_float(packet)

    assert mode == 0
    assert point_count == 1
    assert_in_delta rotation_h, 45.0, 1.0e-6
    assert_in_delta rotation_v, 0.0, 1.0e-6
    assert packet == <<>>
  end

  test "zeros rotation for direction-less region skills" do
    packet = RegionSkill.add(321, skill_cast(false, 45.0))
    {_opcode, packet} = get_short(packet)
    {mode, packet} = get_byte(packet)
    {_source_id, packet} = get_int(packet)
    {_source_id2, packet} = get_int(packet)
    {_next_tick, packet} = get_int(packet)
    {point_count, packet} = get_byte(packet)
    {_point, packet} = get_coord(packet)
    {_skill_id, packet} = get_int(packet)
    {_skill_level, packet} = get_short(packet)
    {rotation_h, packet} = get_float(packet)
    {rotation_v, packet} = get_float(packet)

    assert mode == 0
    assert point_count == 1
    assert_in_delta rotation_h, 0.0, 1.0e-6
    assert_in_delta rotation_v, 0.0, 1.0e-6
    assert packet == <<>>
  end

  defp skill_cast(use_direction, rotation_z) do
    %SkillCast{
      next_tick: 1234,
      skill_id: 500_000,
      skill_level: 1,
      motion_point: 0,
      attack_point: 0,
      position: %Coord{x: 1, y: 2, z: 3},
      rotation: %Coord{x: 0, y: 0, z: rotation_z},
      meta: %{
        levels: %{
          "1" => %{
            motions: [
              %{
                attacks: [
                  %{
                    cube_magic_path_id: 0,
                    skills: [%{splash: %{use_direction: use_direction}}]
                  }
                ]
              }
            ]
          }
        }
      }
    }
  end
end
