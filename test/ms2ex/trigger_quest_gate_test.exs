defmodule Ms2ex.TriggerQuestGateTest do
  use Ms2ex.DataCase, async: true

  alias Ms2ex.Managers.Field.Trigger
  alias Ms2ex.Managers.Quest.Conditions

  # shaped like the knight tutorial's squire-carry quest: one item_move
  # condition against the carried item, completed by placing it at the
  # destination target
  @quest_id 4_000_272

  @quest_metadata %{
    id: @quest_id,
    basic: %{type: :world_quest, event_tag: ""},
    mentoring: nil,
    conditions: [
      %{type: :item_move, value: 1, codes: %{strings: [], integers: [30_000_856], range: nil}}
    ]
  }

  setup do
    stub_metadata(%{"quest:#{@quest_id}" => @quest_metadata})
    :ok
  end

  # the manager state holds only the persisted counters; condition
  # documents resolve from ETS by quest id
  defp started_quest do
    %{
      id: @quest_id,
      quest_id: @quest_id,
      state: :started,
      start_time: :os.system_time(:second),
      conditions: %{0 => 0}
    }
  end

  test "wanted 1 matches a started quest with conditions unmet" do
    assert Trigger.quest_state_matches?(started_quest(), 1)
  end

  test "wanted 2 does not match before the carry completes" do
    refute Trigger.quest_state_matches?(started_quest(), 2)
  end

  test "wanted 2 matches once the item_move condition is met" do
    quest = Conditions.update(started_quest(), :item_move, 1, "", 404, "", 30_000_856)

    refute Trigger.quest_state_matches?(quest, 1)
    assert Trigger.quest_state_matches?(quest, 2)
  end

  test "wanted 1 no longer matches a completable quest" do
    quest = Conditions.update(started_quest(), :item_move, 1, "", 404, "", 30_000_856)

    refute Trigger.quest_state_matches?(quest, 1)
  end

  test "wanted 3 matches only a completed quest" do
    refute Trigger.quest_state_matches?(started_quest(), 3)
    assert Trigger.quest_state_matches?(%{started_quest() | state: :completed}, 3)
  end

  test "wanted 2 no longer matches a completed quest" do
    refute Trigger.quest_state_matches?(%{started_quest() | state: :completed}, 2)
  end

  test "a missing quest never matches" do
    refute Trigger.quest_state_matches?(nil, 1)
    refute Trigger.quest_state_matches?(nil, 2)
    refute Trigger.quest_state_matches?(nil, 3)
  end
end
