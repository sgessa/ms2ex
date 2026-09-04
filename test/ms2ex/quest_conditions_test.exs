defmodule Ms2ex.Managers.Quest.ConditionsTest do
  use ExUnit.Case, async: true

  alias Ms2ex.Managers.Quest.Conditions

  setup do
    quest = %{
      state: :started,
      start_time: :os.system_time(:second),
      metadata: %{basic: %{type: :world_quest}, mentoring: nil},
      conditions: %{
        0 => condition(:npc, 3, codes: [31_000_010]),
        1 => condition(:map, 1, codes: []),
        2 => condition(:level, 1, target: [10])
      }
    }

    %{quest: quest}
  end

  test "progresses code-gated conditions only on matching ids", %{quest: quest} do
    updated = Conditions.update(quest, :npc, 1, "", 2000, "", 31_000_010)

    assert updated.conditions[0].counter == 1
    assert updated.conditions[1].counter == 0
    assert updated.conditions[2].counter == 0
  end

  test "ignores kills of non-matching mobs", %{quest: quest} do
    updated = Conditions.update(quest, :npc, 1, "", 2000, "", 30_999_999)
    assert updated == quest
  end

  test "progresses code-less conditions on any push of the type", %{quest: quest} do
    updated = Conditions.update(quest, :map, 1, "", 0, "", 620_000_000)
    assert updated.conditions[1].counter == 1
  end

  test "riding conditions require the configured map code", %{quest: quest} do
    quest = %{quest | conditions: %{0 => condition(:riding, 200, codes: [20_000_001])}}

    assert Conditions.update(quest, :riding, 1, "", 0, "", 20_000_002) == quest

    updated = Conditions.update(quest, :riding, 1, "", 0, "", 20_000_001)
    assert updated.conditions[0].counter == 1
  end

  test "field missions require the completed mission id", %{quest: quest} do
    quest = %{quest | conditions: %{0 => condition(:field_mission, 1, codes: [72_000_134])}}

    assert Conditions.update(quest, :field_mission, 1, "", 0, "", 72_000_135) == quest

    updated = Conditions.update(quest, :field_mission, 1, "", 0, "", 72_000_134)
    assert updated.conditions[0].counter == 1
  end

  test "target gate requires the pushed value to reach the minimum", %{quest: quest} do
    updated = Conditions.update(quest, :level, 1, "", 9, "", 0)
    assert updated.conditions[2].counter == 0

    updated = Conditions.update(quest, :level, 1, "", 10, "", 0)
    assert updated.conditions[2].counter == 1
  end

  test "counters clamp at the condition value and stay clamped", %{quest: quest} do
    updated = Conditions.update(quest, :npc, 99, "", 0, "", 31_000_010)
    assert updated.conditions[0].counter == 3

    updated = Conditions.update(updated, :npc, 1, "", 0, "", 31_000_010)
    assert updated.conditions[0].counter == 3
  end

  test "completed quests never progress", %{quest: quest} do
    quest = %{quest | state: :completed}
    updated = Conditions.update(quest, :npc, 1, "", 0, "", 31_000_010)
    assert updated == quest
  end

  defp condition(type, value, opts) do
    codes = Keyword.get(opts, :codes)
    target = Keyword.get(opts, :target)

    %{
      counter: 0,
      metadata: %{
        type: type,
        value: value,
        codes: parameter_doc(codes),
        target: parameter_doc(target)
      }
    }
  end

  defp parameter_doc(nil), do: nil
  defp parameter_doc(list), do: %{strings: [], integers: list, range: nil}
end
