defmodule Ms2ex.Managers.Quest.Requirements do
  @moduledoc """
  Functions for checking if quest requirements are met.

  This module provides utilities to check various requirements for starting quests,
  including level, job, gear score, and prerequisite quests.
  """

  alias Ms2ex.Managers

  @doc """
  Checks if a character can start a quest based on its metadata requirements.

  ## Parameters
    * `character` - The character attempting to start the quest
    * `metadata` - The quest metadata containing requirements
    * `state` - The current quest manager state

  ## Returns
    * `true` - Character meets all requirements
    * `false` - Character does not meet all requirements
  """
  def can_start?(_character, %{disabled: true}) do
    false
  end

  def can_start?(character, metadata, state) do
    req = metadata.require

    # Quest requirements checks
    meet_level_req?(character, req) &&
      meet_job_req?(character, req.job) &&
      meet_gear_score_req?(character, req.gear_score) &&
      meet_achievement_req?(character, req) &&
      meet_quests_req?(req.quest, state) &&
      meet_selectable_quests_req?(req.selectable_quest, state) &&
      check_event_tag(character, metadata.basic.event_tag)
  end

  defp check_event_tag(_character, _event_tag) do
    # TODO: Implement event tag checking when event system is available
    # This should check if the event_tag is currently active in the game
    # For now, return true to not block quest progression
    true
  end

  defp meet_level_req?(character, req) do
    req_level = req.level || 0
    max_level = req.max_level || 0

    if req_level > 0 && character.level < req_level do
      false
    else
      max_level == 0 || character.level <= max_level
    end
  end

  defp meet_job_req?(character, req_jobs) do
    Enum.empty?(req_jobs) || Enum.member?(req_jobs, character.job)
  end

  defp meet_quests_req?([], _state), do: true

  defp meet_quests_req?(pre_quests, state) do
    Enum.all?(pre_quests, fn quest_id ->
      case Managers.Quest.State.get_quest_from_state(quest_id, state) do
        nil -> false
        quest -> quest.state == :completed
      end
    end)
  end

  defp meet_selectable_quests_req?([], _state) do
    true
  end

  defp meet_selectable_quests_req?(selectable_quests, state) do
    Enum.any?(selectable_quests, fn quest_id ->
      case Managers.Quest.State.get_quest_from_state(quest_id, state) do
        nil -> false
        quest -> quest.state == :completed
      end
    end)
  end

  defp meet_gear_score_req?(character, req_gear_score) do
    req_gear_score <= 0 ||
      Map.get(character.stats, :gear_score, 0) >= req_gear_score
  end

  defp meet_achievement_req?(_character, _metadata) do
    # TODO
    true
  end
end
