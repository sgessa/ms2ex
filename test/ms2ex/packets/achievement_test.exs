defmodule Ms2ex.Packets.AchievementTest do
  use ExUnit.Case, async: true

  alias Ms2ex.Packets.Achievement

  import Ms2ex.Packets.PacketReader

  test "serializes completed achievement state and grades" do
    achievement = %{
      achievement_id: 101,
      current_grade: 2,
      reward_grade: 1,
      favorite: true,
      counter: 20,
      grades: %{"1" => 100, "2" => 200},
      metadata: %{grades: %{"1" => %{}, "2" => %{}}}
    }

    {opcode, packet} = Achievement.update(achievement) |> get_short()
    {command, packet} = get_byte(packet)
    {achievement_id, packet} = get_int(packet)
    {status, packet} = get_byte(packet)
    {completed, packet} = get_int(packet)
    {current_grade, packet} = get_int(packet)
    {reward_grade, packet} = get_int(packet)
    {favorite, packet} = get_bool(packet)
    {counter, packet} = get_long(packet)
    {grade_count, packet} = get_int(packet)
    {first_grade, packet} = get_int(packet)
    {first_time, packet} = get_long(packet)
    {second_grade, packet} = get_int(packet)
    {second_time, packet} = get_long(packet)

    assert {opcode, command, achievement_id} == {0x5F, 0x02, 101}

    assert {status, completed, current_grade, reward_grade, favorite, counter} ==
             {3, 1, 2, 1, true, 20}

    assert {grade_count, first_grade, first_time, second_grade, second_time} ==
             {2, 1, 100, 2, 200}

    assert packet == <<>>
  end
end
