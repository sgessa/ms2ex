defmodule Ms2ex.Managers.Quest.Conditions do
  @moduledoc """
  Functions for managing quest conditions and checking their status.

  This module provides utilities to check and update quest conditions
  based on various player actions and game events.
  """

  # No aliases needed

  @doc """
  Checks if all conditions for a quest are met.

  ## Parameters
    * `quest` - The quest to check conditions for

  ## Returns
    * `true` - All conditions are met
    * `false` - At least one condition is not met
  """
  def all_met?(quest) do
    Enum.all?(quest.conditions, fn {_idx, condition} ->
      condition.counter >= condition.metadata.value
    end)
  end

  @doc """
  Updates quest conditions based on a condition type.

  ## Parameters
    * `quest` - The quest to update
    * `condition_type` - The type of condition being updated
    * `counter` - The amount to increase the condition counter by
    * `target_string` - String target parameter (depends on condition type)
    * `target_long` - Integer target parameter (depends on condition type)
    * `code_string` - String code parameter (depends on condition type)
    * `code_long` - Integer code parameter (depends on condition type)

  ## Returns
    * The original quest if no changes were made, or an updated quest
  """
  def update(
        quest,
        condition_type,
        counter,
        target_string,
        target_long,
        code_string,
        code_long
      ) do
    # Skip if quest isn't active
    if quest.state != :started do
      quest
    else
      # Special handling for mentoring quests
      if quest.metadata && quest.metadata.basic && quest.metadata.basic.type == :mentoring_mission &&
           quest.metadata.mentoring do
        # Check if required opening days haven't passed
        now = :os.system_time(:second)
        # seconds in a day
        days_passed = (now - quest.start_time) / 86400

        if days_passed < quest.metadata.mentoring.opening_day do
          quest
        end
      end

      # Find conditions that match the condition type
      matching_conditions =
        quest.conditions
        |> Enum.filter(fn {_idx, condition} ->
          # Only update if condition type matches and not already completed
          condition.metadata.type == condition_type &&
            condition.counter < condition.metadata.value
        end)
        |> Enum.filter(fn {_idx, condition} ->
          # Additional check based on metadata
          valid_condition_type?(
            condition.metadata,
            target_string,
            target_long,
            code_string,
            code_long
          )
        end)

      # If no matching conditions, return original quest
      if Enum.empty?(matching_conditions) do
        quest
      else
        # Update the condition counters
        updated_conditions =
          Enum.reduce(matching_conditions, quest.conditions, fn {idx, _condition}, acc ->
            Map.update!(acc, idx, fn condition ->
              new_counter = min(condition.metadata.value, condition.counter + counter)
              %{condition | counter: new_counter}
            end)
          end)

        # Return updated quest with new conditions
        %{quest | conditions: updated_conditions}
      end
    end
  end

  @doc """
  Validates if a condition's metadata matches the given parameters.

  ## Parameters
    * `metadata` - The condition metadata
    * `target_string` - String target parameter
    * `target_long` - Integer target parameter
    * `code_string` - String code parameter
    * `code_long` - Integer code parameter

  ## Returns
    * `true` - The condition matches the parameters
    * `false` - The condition does not match the parameters
  """
  def valid_condition_type?(metadata, target_string, target_long, _code_string, code_long) do
    case metadata.type do
      # Using atoms with values that directly match Maple2's ConditionType enum
      :hunt_monster ->
        metadata.target_ids == [] || Enum.member?(metadata.target_ids, target_long)

      :complete_map_all ->
        metadata.target_ids == [] || Enum.member?(metadata.target_ids, target_long)

      :collect_item ->
        Enum.empty?(metadata.target_ids) || Enum.member?(metadata.target_ids, target_long)

      :harvest_all ->
        metadata.target_ids == [] || Enum.member?(metadata.target_ids, target_long)

      :skill_use ->
        metadata.target_ids == [] || Enum.member?(metadata.target_ids, target_long)

      :talk_npc ->
        metadata.target_ids == [] || Enum.member?(metadata.target_ids, target_long)

      :visit_npc ->
        metadata.target_ids == [] || Enum.member?(metadata.target_ids, target_long)

      :quest ->
        metadata.target_ids == [] || Enum.member?(metadata.target_ids, code_long)

      :quest_clear ->
        metadata.target_ids == [] || Enum.member?(metadata.target_ids, code_long)

      :interact_object ->
        check_string_match(metadata.target_ids_str, target_string) ||
          check_number_match(metadata.target_ids, target_long)

      # Add other condition types as needed
      _ ->
        true
    end
  end

  # Helper functions

  defp check_string_match(nil, _target), do: false
  defp check_string_match([], _target), do: false
  defp check_string_match(list, target) when is_list(list), do: Enum.member?(list, target)
  defp check_string_match(_list, _target), do: false

  defp check_number_match(nil, _target), do: false
  defp check_number_match([], _target), do: false
  defp check_number_match(list, target) when is_list(list), do: Enum.member?(list, target)
  defp check_number_match(_list, _target), do: false
end
