defmodule Ms2ex.Packets.QuestTest do
  use ExUnit.Case, async: true

  alias Ms2ex.Packets.Game.Quest

  import Ms2ex.Packets.PacketReader

  test "load_quest_states writes enum state ids and preserves condition order" do
    packet =
      Quest.load_quest_states([
        %{
          quest_id: 401,
          state: :started,
          completion_count: 2,
          start_time: 11,
          end_time: 22,
          track: true,
          conditions: %{
            2 => %{counter: 9},
            0 => %{counter: 7},
            1 => %{counter: 8}
          }
        }
      ])

    {_opcode, packet} = get_short(packet)
    {command, packet} = get_byte(packet)
    {count, packet} = get_int(packet)
    {quest_id, packet} = get_int(packet)
    {state, packet} = get_int(packet)
    {completion_count, packet} = get_int(packet)
    {start_time, packet} = get_long(packet)
    {end_time, packet} = get_long(packet)
    {track?, packet} = get_bool(packet)
    {condition_count, packet} = get_int(packet)
    {counter_0, packet} = get_int(packet)
    {counter_1, packet} = get_int(packet)
    {counter_2, packet} = get_int(packet)

    assert command == 0x16
    assert count == 1
    assert quest_id == 401
    assert state == 1
    assert completion_count == 2
    assert start_time == 11
    assert end_time == 22
    assert track?
    assert condition_count == 3
    assert {counter_0, counter_1, counter_2} == {7, 8, 9}
    assert packet == <<>>
  end

  test "load_quest_states with multiple quests keeps per-quest field alignment" do
    packet =
      Quest.load_quest_states([
        %{
          quest_id: 1,
          state: :completed,
          completion_count: 0,
          start_time: 5,
          end_time: 6,
          track: false,
          conditions: %{}
        },
        %{
          quest_id: 2,
          state: :started,
          completion_count: 0,
          start_time: 7,
          end_time: 0,
          track: true,
          conditions: %{0 => %{counter: 1}}
        }
      ])

    {_opcode, packet} = get_short(packet)
    {_command, packet} = get_byte(packet)
    {count, packet} = get_int(packet)

    {quest_id, packet} = get_int(packet)
    {state, packet} = get_int(packet)
    {_completion_count, packet} = get_int(packet)
    {_start_time, packet} = get_long(packet)
    {_end_time, packet} = get_long(packet)
    {_track?, packet} = get_bool(packet)
    {conditions, packet} = get_int(packet)

    assert count == 2
    assert quest_id == 1
    assert state == 2
    assert conditions == 0

    {quest_id, packet} = get_int(packet)
    {state, packet} = get_int(packet)
    {_completion_count, packet} = get_int(packet)
    {_start_time, packet} = get_long(packet)
    {_end_time, packet} = get_long(packet)
    {_track?, packet} = get_bool(packet)
    {conditions, packet} = get_int(packet)
    {counter, packet} = get_int(packet)

    assert quest_id == 2
    assert state == 1
    assert conditions == 1
    assert counter == 1
    assert packet == <<>>
  end
end
