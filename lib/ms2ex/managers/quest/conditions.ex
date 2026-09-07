defmodule Ms2ex.Managers.Quest.Conditions do
  @moduledoc """
  Quest condition helpers.

  A quest in the manager state carries only its persisted condition
  counters (`%{index => counter}`); the condition documents — type, value,
  codes, target — live in the quest's storage metadata and are resolved
  from ETS as each event is matched.

  Progress matching follows the metadata layout: `codes` carry the event id
  the condition is gated on (npc id, item id, skill id, map id, ...), while
  `target` optionally carries a minimum-value gate the pushed value must
  reach for the progress to count.
  """

  alias Ms2ex.Storage

  # condition types whose progress is gated on the code parameter matching
  # one of the configured integers (or falling inside a configured range)
  @code_types [
    :continent,
    :dialogue,
    :explore,
    :explore_continent,
    :field_mission,
    :fish,
    :fish_big,
    :fish_collect,
    :fish_fail,
    :fish_goldmedal,
    :fish_success_bait,
    :interact_object,
    :interact_object_rep,
    :item_add,
    :item_destroy,
    :item_exist,
    :item_pickup,
    :job,
    :job_change,
    :level,
    :level_up,
    :map,
    :mastery_farming,
    :mastery_farming_try,
    :mastery_gathering,
    :mastery_gathering_try,
    :mastery_grade,
    :mastery_harvest,
    :mastery_harvest_try,
    :mastery_manufacturing,
    :set_mastery_grade,
    :fisher_grade,
    :music_play_ensemble_in,
    :music_play_instrument_mastery,
    :music_play_instrument_time,
    :music_play_score,
    :npc,
    :quest,
    :quest_accept,
    :quest_clear,
    :quest_clear_by_chapter,
    :riding,
    :run,
    :swim,
    :climb,
    :glide,
    :crawl,
    :fall,
    :skill,
    :stay_cube,
    :stay_map,
    :talk_in,
    # meta-trophies tracking other achievements: the pushed code is the
    # completing achievement id; without the gate every grade completion
    # counts into every meta-trophy
    :revise_achieve_multi_grade,
    :revise_achieve_single_grade,
    :hero_achieve,
    :hero_achieve_grade
  ]

  # condition types whose target parameter acts as a minimum-value gate: the
  # pushed value must reach at least one of the configured integers
  @target_min_types [
    :enchant_result,
    :gemstone_upgrade,
    :install_billboard,
    :item_move,
    :level,
    :level_up,
    :npc,
    :socket_unlock
  ]

  # condition types whose target integers enumerate allowed values (e.g. map
  # ids) that the pushed value must match exactly
  @target_equality_types [
    :chat,
    :emotion,
    # the fishing conditions carry the map the fish was caught in
    :fish,
    :fish_big,
    :fish_collect,
    :fish_fail,
    :fish_goldmedal,
    :fish_success_bait,
    :holdtime,
    :laddertime,
    :ropetime,
    # the pushed target is the achieved grade of the tracked trophy
    :revise_achieve_multi_grade,
    :revise_achieve_single_grade,
    :hero_achieve,
    :hero_achieve_grade
  ]

  # every condition of the quest reached its configured value; unknown
  # metadata (or a quest without conditions) counts as met
  def all_met?(quest) do
    quest
    |> condition_docs()
    |> Enum.with_index()
    |> Enum.all?(fn {doc, index} -> counter(quest.conditions, index) >= doc.value end)
  end

  # progress the quest's counters for one gameplay event; returns the quest
  # unchanged when the event matches no condition (or can no longer count).
  # the metadata has no string target gates, so the pushed target string is
  # not matched
  def update(quest, condition_type, counter, _target_string, target_long, code_string, code_long) do
    metadata = Storage.Quests.get_meta(quest.quest_id)

    if quest.state != :started or mentoring_locked?(quest, metadata) do
      quest
    else
      matching =
        quest
        |> condition_docs(metadata)
        |> Enum.with_index()
        |> Enum.filter(fn {doc, index} ->
          condition_matches?(
            doc,
            index,
            quest.conditions,
            condition_type,
            target_long,
            code_string,
            code_long
          )
        end)

      apply_updates(quest, matching, counter)
    end
  end

  @doc """
  Whether one condition document accepts the pushed event: the code
  parameter must satisfy the condition's code gate (string codes match the
  pushed string, integer codes the pushed long) and the pushed value its
  target gate. Shared with the achievement conditions, which follow the
  same metadata layout.
  """
  def metadata_matches?(doc, _target_string, target_long, code_string, code_long) do
    code_ok?(doc, code_string, code_long) and target_ok?(doc, target_long)
  end

  # the condition document list is indexed by position; the manager state
  # holds the matching counters by that same index
  defp condition_docs(quest) do
    condition_docs(quest, Storage.Quests.get_meta(quest.quest_id))
  end

  defp condition_docs(_quest, %{conditions: docs}) when is_list(docs), do: docs
  defp condition_docs(_quest, _metadata), do: []

  defp counter(conditions, index), do: Map.get(conditions, index, 0)

  defp condition_matches?(
         doc,
         index,
         conditions,
         condition_type,
         target_long,
         code_string,
         code_long
       ) do
    doc.type == condition_type and
      counter(conditions, index) < doc.value and
      metadata_matches?(doc, "", target_long, code_string, code_long)
  end

  defp apply_updates(quest, [], _counter), do: quest

  defp apply_updates(quest, matching, counter) do
    conditions =
      Enum.reduce(matching, quest.conditions, fn {doc, index}, conditions ->
        Map.update!(conditions, index, fn held -> min(doc.value, held + counter) end)
      end)

    %{quest | conditions: conditions}
  end

  # the code gate: conditions configured with string codes match the
  # pushed code string (emote keys, trigger names, npc races, ...);
  # integer-gated types match the pushed long against the configured ids
  # or range; conditions without a code parameter accept any event of the
  # type
  defp code_ok?(doc, code_string, code_long) do
    strings = parameter_strings(doc[:codes])
    integers = parameter_integers(doc[:codes])
    range = parameter_range(doc[:codes])

    cond do
      strings != [] ->
        code_string in strings

      doc.type in @code_types and (integers != [] or range != nil) ->
        code_long in integers or in_range?(range, code_long)

      true ->
        true
    end
  end

  defp target_ok?(%{type: type} = doc, target_long) do
    integers = parameter_integers(doc[:target])

    cond do
      type in @target_min_types -> integers == [] or Enum.any?(integers, &(&1 <= target_long))
      type in @target_equality_types -> integers == [] or Enum.member?(integers, target_long)
      true -> true
    end
  end

  # mentoring missions only progress after the relationship's opening day
  defp mentoring_locked?(quest, %{
         basic: %{type: :mentoring_mission},
         mentoring: %{opening_day: opening_day}
       })
       when is_integer(opening_day) do
    now = :os.system_time(:second)
    days_passed = (now - quest.start_time) / 86_400
    days_passed < opening_day
  end

  defp mentoring_locked?(_quest, _metadata), do: false

  defp parameter_strings(nil), do: []
  defp parameter_strings(%{strings: strings}) when is_list(strings), do: strings
  defp parameter_strings(_value), do: []

  defp parameter_integers(nil), do: []
  defp parameter_integers(%{integers: integers}) when is_list(integers), do: integers
  defp parameter_integers(_value), do: []

  defp parameter_range(nil), do: nil

  defp parameter_range(%{range: %{min: min, max: max}}) do
    %{min: min, max: max}
  end

  defp parameter_range(_value), do: nil

  defp in_range?(nil, _value), do: false
  defp in_range?(%{min: min, max: max}, value), do: value >= min and value <= max
end
