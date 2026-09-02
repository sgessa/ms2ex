defmodule Ms2ex.Packets.RegionSkillTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Ms2ex.Packets.RegionSkill
  alias Ms2ex.Types.Coord
  alias Ms2ex.Types.SkillCast

  import Ms2ex.Packets.PacketReader
  import Ms2ex.TestHelpers

  setup do
    stub_metadata(%{
      "table:magicpath.xml" => %{
        table: %{
          entries: %{
            "103000111" => [
              %{rotate?: true, fire_offset: %{x: 0.0, y: 450.0, z: 0.0}}
            ]
          }
        }
      }
    })

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

  test "rotates region points with the caster facing" do
    packet = RegionSkill.add(321, flame_tornado_cast())
    {_opcode, packet} = get_short(packet)
    {_mode, packet} = get_byte(packet)
    {_source_id, packet} = get_int(packet)
    {_source_id2, packet} = get_int(packet)
    {_next_tick, packet} = get_int(packet)
    {_point_count, packet} = get_byte(packet)
    {point, _packet} = get_coord(packet)

    assert_in_delta point.x, -317.198, 0.01
    assert_in_delta point.y, 320.198, 0.01
    assert_in_delta point.z, 3.0, 1.0e-6
  end

  test "splash_skill_cast skips non-splash side effects" do
    {splash_cast, splash} = SkillCast.splash_skill_cast(flame_tornado_cast())

    assert splash_cast.skill_id == 10_300_012
    assert splash_cast.skill_level == 10
    assert splash.interval == 300
    assert splash.fire_count == 5
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
                    skills: [%{has_splash: true, splash: %{use_direction: use_direction}}]
                  }
                ]
              }
            ]
          }
        }
      }
    }
  end

  defp flame_tornado_cast do
    %SkillCast{
      next_tick: 1234,
      skill_id: 10_300_011,
      skill_level: 10,
      motion_point: 0,
      attack_point: 0,
      position: %Coord{x: 1, y: 2, z: 3},
      rotation: %Coord{x: 0, y: 0, z: 225.0},
      caster: %Ms2ex.Schema.Character{id: 1},
      meta: %{
        levels: %{
          "10" => %{
            motions: [
              %{
                attacks: [
                  %{
                    cube_magic_path_id: 103_000_111,
                    skills: [
                      %{id: 10_300_241, level: 1, has_splash: false, splash: %{}},
                      %{
                        id: 10_300_012,
                        level: 10,
                        has_splash: true,
                        splash: %{
                          interval: 300,
                          fire_count: 5,
                          remove_delay: 0,
                          use_direction: true
                        }
                      }
                    ]
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
