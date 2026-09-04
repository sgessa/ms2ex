defmodule Ms2ex.Managers.Quest.Conditions do
  @moduledoc """
  Quest condition helpers.

  Progress matching follows the metadata layout: `codes` carry the event id
  the condition is gated on (npc id, item id, skill id, map id, ...), while
  `target` optionally carries a minimum-value gate the pushed value must
  reach for the progress to count.
  """

  # condition types whose progress is gated on the code parameter matching
  # one of the configured integers (or falling inside a configured range)
  @code_types [
    :continent,
    :dialogue,
    :explore,
    :explore_continent,
    :field_mission,
    :fish,
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
    :music_play_ensemble_in,
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
    :talk_in
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
  @target_equality_types [:chat, :emotion, :holdtime, :laddertime, :ropetime]

  def all_met?(quest) do
    Enum.all?(quest.conditions, fn {_idx, condition} ->
      condition.counter >= condition.metadata.value
    end)
  end

  def update(
        quest,
        condition_type,
        counter,
        target_string,
        target_long,
        code_string,
        code_long
      ) do
    if quest.state != :started or mentoring_locked?(quest) do
      quest
    else
      matching_indexes =
        quest.conditions
        |> Enum.filter(fn {_idx, condition} ->
          condition_matches?(
            condition,
            condition_type,
            target_string,
            target_long,
            code_string,
            code_long
          )
        end)
        |> Enum.map(&elem(&1, 0))

      apply_updates(quest, matching_indexes, counter)
    end
  end

  defp apply_updates(quest, [], _counter), do: quest

  defp apply_updates(quest, indexes, counter) do
    updated_conditions =
      Enum.reduce(indexes, quest.conditions, fn index, conditions ->
        Map.update!(conditions, index, fn condition ->
          new_counter = min(condition.metadata.value, condition.counter + counter)
          %{condition | counter: new_counter}
        end)
      end)

    %{quest | conditions: updated_conditions}
  end

  defp condition_matches?(
         condition,
         condition_type,
         target_string,
         target_long,
         code_string,
         code_long
       ) do
    condition.metadata.type == condition_type and
      condition.counter < condition.metadata.value and
      metadata_matches?(condition.metadata, target_string, target_long, code_string, code_long)
  end

  def metadata_matches?(metadata, _target_string, target_long, _code_string, code_long) do
    code_ok?(metadata, code_long) and target_ok?(metadata, target_long)
  end

  defp code_ok?(%{type: type} = metadata, code_long) do
    if type in @code_types do
      strings = parameter_strings(metadata[:codes])
      integers = parameter_integers(metadata[:codes])
      range = parameter_range(metadata[:codes])

      cond do
        strings != [] ->
          Enum.member?(strings, code_long)

        integers != [] or range != nil ->
          Enum.member?(integers, code_long) or in_range?(range, code_long)

        true ->
          true
      end
    else
      true
    end
  end

  defp target_ok?(%{type: type} = metadata, target_long) do
    integers = parameter_integers(metadata[:target])

    cond do
      type in @target_min_types -> integers == [] or Enum.any?(integers, &(&1 <= target_long))
      type in @target_equality_types -> integers == [] or Enum.member?(integers, target_long)
      true -> true
    end
  end

  defp mentoring_locked?(quest) do
    case quest.metadata do
      %{basic: %{type: :mentoring_mission}, mentoring: %{opening_day: opening_day}} ->
        now = :os.system_time(:second)
        days_passed = (now - quest.start_time) / 86_400
        days_passed < opening_day

      _ ->
        false
    end
  end

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
