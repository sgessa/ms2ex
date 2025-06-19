defmodule Ms2ex.Enums.QuestError do
  @moduledoc """
  Enum for quest error codes.
  Ported from Maple2's QuestError enum.
  """

  use Ms2ex.Enum, %{
    none: 0,
    quest_accept_fail: 1,
    quest_not_found: 2,
    quest_complete_fail: 3,
    quest_abandon_restrict: 4,
    quest_abandon_fail: 5,
    quest_npc_fail: 6,
    quest_already_done: 7,
    quest_category_mission_fail: 8,
    quest_level_fail: 9,
    quest_job_fail: 10,
    quest_fail: 11,
    quest_not_possible: 12,
    quest_item_check_fail: 13,
    quest_not_complete: 14,
    quest_not_have_reward_lot: 15,
    quest_exchange_fail: 16,
    quest_legacy_quest: 17,
    quest_already_have_legend_item: 18,
    quest_faction_check_fail: 19,
    quest_mastery_fail: 20,
    quest_accept_quest_full: 21,
    quest_send_event_fail: 22
  }
end
