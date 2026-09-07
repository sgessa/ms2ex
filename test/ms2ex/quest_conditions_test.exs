defmodule Ms2ex.Managers.Quest.ConditionsTest do
  use Ms2ex.DataCase, async: true

  alias Ms2ex.Managers.Quest.Conditions

  @quest_id 5001

  setup do
    stub_metadata(%{
      "quest:#{@quest_id}" => %{
        id: @quest_id,
        basic: %{type: :world_quest},
        mentoring: nil,
        conditions: [
          condition_doc(:npc, 3, codes: [31_000_010]),
          condition_doc(:map, 1, codes: []),
          condition_doc(:level, 1, target: [10])
        ]
      }
    })

    quest = %{
      id: @quest_id,
      quest_id: @quest_id,
      state: :started,
      start_time: :os.system_time(:second),
      conditions: %{0 => 0, 1 => 0, 2 => 0}
    }

    %{quest: quest}
  end

  test "progresses code-gated conditions only on matching ids", %{quest: quest} do
    updated = Conditions.update(quest, :npc, 1, "", 2000, "", 31_000_010)

    assert updated.conditions[0] == 1
    assert updated.conditions[1] == 0
    assert updated.conditions[2] == 0
  end

  test "ignores kills of non-matching mobs", %{quest: quest} do
    updated = Conditions.update(quest, :npc, 1, "", 2000, "", 30_999_999)
    assert updated == quest
  end

  test "progresses code-less conditions on any push of the type", %{quest: quest} do
    updated = Conditions.update(quest, :map, 1, "", 0, "", 620_000_000)
    assert updated.conditions[1] == 1
  end

  # the knight main quest's gate: quest 60100001 completes on the scripted
  # set_achievement event (trigger code "jordy") fired from 52000116_qd
  test "trigger conditions progress on the scripted achievement event" do
    stub_metadata(%{
      "quest:#{@quest_id}" => %{
        id: @quest_id,
        basic: %{type: :world_quest},
        mentoring: nil,
        conditions: [
          %{
            type: :trigger,
            value: 1,
            codes: %{strings: ["jordy"], integers: [], range: nil},
            target: %{strings: [], integers: [], range: nil}
          }
        ]
      }
    })

    quest = %{
      id: @quest_id,
      quest_id: @quest_id,
      state: :started,
      start_time: :os.system_time(:second),
      conditions: %{0 => 0}
    }

    updated = Conditions.update(quest, :trigger, 1, "", 0, "jordy", 0)
    assert updated.conditions[0] == 1

    # a different trigger code must not count (other scripts fire their own)
    assert Conditions.update(quest, :trigger, 1, "", 0, "rescueskyfortress", 0) == quest
  end

  # emotion conditions gate on the client-sent emote key plus the map
  test "emotion conditions require the configured emote key" do
    stub_metadata(%{
      "quest:#{@quest_id}" => %{
        id: @quest_id,
        basic: %{type: :world_quest},
        mentoring: nil,
        conditions: [
          %{
            type: :emotion,
            value: 1,
            codes: %{strings: ["hello"], integers: [], range: nil},
            target: %{strings: [], integers: [2_000_062], range: nil}
          }
        ]
      }
    })

    quest = %{
      id: @quest_id,
      quest_id: @quest_id,
      state: :started,
      start_time: :os.system_time(:second),
      conditions: %{0 => 0}
    }

    # a different emote on the right map does not count
    assert Conditions.update(quest, :emotion, 1, "", 2_000_062, "greet", 0) == quest

    # the configured emote on the configured map does
    updated = Conditions.update(quest, :emotion, 1, "", 2_000_062, "hello", 0)
    assert updated.conditions[0] == 1
  end

  test "riding conditions require the configured map code", %{quest: quest} do
    stub_metadata(%{
      "quest:#{@quest_id}" => %{
        id: @quest_id,
        basic: %{type: :world_quest},
        mentoring: nil,
        conditions: [condition_doc(:riding, 200, codes: [20_000_001])]
      }
    })

    quest = put_in(quest.conditions, %{0 => 0})

    assert Conditions.update(quest, :riding, 1, "", 0, "", 20_000_002) == quest

    updated = Conditions.update(quest, :riding, 1, "", 0, "", 20_000_001)
    assert updated.conditions[0] == 1
  end

  test "field missions require the completed mission id", %{quest: quest} do
    stub_metadata(%{
      "quest:#{@quest_id}" => %{
        id: @quest_id,
        basic: %{type: :world_quest},
        mentoring: nil,
        conditions: [condition_doc(:field_mission, 1, codes: [72_000_134])]
      }
    })

    quest = put_in(quest.conditions, %{0 => 0})

    assert Conditions.update(quest, :field_mission, 1, "", 0, "", 72_000_135) == quest

    updated = Conditions.update(quest, :field_mission, 1, "", 0, "", 72_000_134)
    assert updated.conditions[0] == 1
  end

  test "target gate requires the pushed value to reach the minimum", %{quest: quest} do
    updated = Conditions.update(quest, :level, 1, "", 9, "", 0)
    assert updated.conditions[2] == 0

    updated = Conditions.update(quest, :level, 1, "", 10, "", 0)
    assert updated.conditions[2] == 1
  end

  test "counters clamp at the condition value and stay clamped", %{quest: quest} do
    updated = Conditions.update(quest, :npc, 99, "", 0, "", 31_000_010)
    assert updated.conditions[0] == 3

    updated = Conditions.update(updated, :npc, 1, "", 0, "", 31_000_010)
    assert updated.conditions[0] == 3
  end

  test "completed quests never progress", %{quest: quest} do
    quest = %{quest | state: :completed}
    updated = Conditions.update(quest, :npc, 1, "", 0, "", 31_000_010)
    assert updated == quest
  end

  defp condition_doc(type, value, opts) do
    codes = Keyword.get(opts, :codes)
    target = Keyword.get(opts, :target)

    %{
      type: type,
      value: value,
      codes: parameter_doc(codes),
      target: parameter_doc(target)
    }
  end

  defp parameter_doc(nil), do: nil
  defp parameter_doc(list), do: %{strings: [], integers: list, range: nil}
end
