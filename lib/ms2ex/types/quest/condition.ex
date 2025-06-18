defmodule Ms2ex.Types.Quest.Condition do
  @moduledoc """
  Module for handling quest condition checks.
  Ported from Maple2's QuestCondition.cs
  """

  @doc """
  Checks if a condition is met based on its type and parameters.
  Returns true if the condition is met, false otherwise.

  Parameters:
  * condition_type: The type of condition to check
  * character: The character to check the condition for
  * metadata: The condition metadata to check against
  * target_string: String parameter for condition (e.g., target name)
  * target_long: Integer parameter for condition (e.g., target ID)
  * code_string: String parameter for condition code (e.g., item tag)
  * code_long: Integer parameter for condition code (e.g., item ID)
  """
  def check(
        condition_type,
        character,
        metadata,
        target_string \\ "",
        target_long \\ 0,
        code_string \\ "",
        code_long \\ 0
      ) do
    case condition_type do
      :hunt_monster -> check_hunt_monster(metadata, target_long, code_long)
      :interact_object -> check_interact_object(metadata, target_long, code_long)
      :collect_item -> check_collect_item(metadata, target_long, code_long)
      :talk_npc -> check_talk_npc(metadata, target_long)
      :level_up -> check_level_up(metadata, character)
      :quest -> check_quest(metadata, character, code_long)
      :quest_accept -> check_quest_accept(metadata, code_long)
      :quest_clear -> check_quest_clear(metadata, code_long)
      _ -> check_default(metadata, target_string, target_long, code_string, code_long)
    end
  end

  # Private functions for specific condition checks

  defp check_hunt_monster(metadata, _target_id, monster_id) do
    # Check if the monster ID matches one of the valid IDs in metadata
    # In actual implementation, would check if target_id matches specific map constraints too
    if metadata.monster_ids != nil do
      monster_id in metadata.monster_ids
    else
      true
    end
  end

  defp check_interact_object(metadata, _target_id, object_id) do
    # Check if the object ID matches the one in metadata
    if metadata.object_id != nil && metadata.object_id > 0 do
      metadata.object_id == object_id
    else
      true
    end
  end

  defp check_collect_item(metadata, _target_id, item_id) do
    # Check if the item ID matches the one in metadata
    if metadata.item_id != nil && metadata.item_id > 0 do
      metadata.item_id == item_id
    else
      true
    end
  end

  defp check_talk_npc(metadata, npc_id) do
    # Check if the NPC ID matches the one in metadata
    if metadata.npc_id != nil && metadata.npc_id > 0 do
      metadata.npc_id == npc_id
    else
      true
    end
  end

  defp check_level_up(metadata, character) do
    # Check if character's level meets the condition
    if metadata.level != nil && metadata.level > 0 do
      character.level >= metadata.level
    else
      true
    end
  end

  defp check_quest(metadata, _character, quest_id) do
    # Check if a specific quest is active or completed
    if metadata.required_quest_id != nil && metadata.required_quest_id > 0 do
      quest_id == metadata.required_quest_id
    else
      true
    end
  end

  defp check_quest_accept(_metadata, quest_id) do
    # Condition passes when a quest is accepted
    quest_id > 0
  end

  defp check_quest_clear(_metadata, quest_id) do
    # Condition passes when a quest is cleared
    quest_id > 0
  end

  defp check_default(_metadata, _target_string, _target_long, _code_string, _code_long) do
    # Default handler for condition types not specifically implemented
    # For now, returns true to avoid blocking quest progress
    true
  end

  @doc """
  Updates quest condition progress for a character.
  Returns updated conditions map.
  """
  def update_progress(
        conditions,
        condition_type,
        character,
        counter \\ 1,
        target_string \\ "",
        target_long \\ 0,
        code_string \\ "",
        code_long \\ 0
      ) do
    Enum.reduce(conditions, conditions, fn {index, condition}, acc ->
      if condition.metadata.type == condition_type &&
           condition.counter < condition.metadata.value &&
           check(
             condition_type,
             character,
             condition.metadata,
             target_string,
             target_long,
             code_string,
             code_long
           ) do
        updated_counter = min(condition.metadata.value, condition.counter + counter)
        Map.put(acc, index, %{condition | counter: updated_counter})
      else
        acc
      end
    end)
  end
end
