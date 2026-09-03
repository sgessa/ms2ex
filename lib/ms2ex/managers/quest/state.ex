defmodule Ms2ex.Managers.Quest.State do
  @moduledoc """
  Helper functions for managing quest state.

  This module provides utilities to create, update, and manage quests in the state.
  It handles operations like quest creation, completion, abandonment, and tracking.
  """

  alias Ms2ex.{Context, Storage}

  @doc """
  Creates a new quest for a character.

  ## Parameters
    * `character` - The character struct
    * `quest_metadata` - The metadata for the quest to create

  ## Returns
    * `{:ok, quest}` - Successfully created quest
    * `{:error, changeset}` - Failed to create quest
  """
  def create_quest(character, quest_metadata) do
    now = :os.system_time(:second)

    owner_id = Storage.Quests.get_owner_id(character, quest_metadata)
    account_quest? = Storage.Quests.account_quest?(quest_metadata)

    conditions =
      quest_metadata.conditions
      |> Enum.with_index()
      |> Enum.map(fn {metadata, index} ->
        {index, %{counter: 0, metadata: metadata}}
      end)
      |> Enum.into(%{})

    quest_attrs = %{
      owner_id: owner_id,
      quest_id: quest_metadata.id,
      state: :started,
      start_time: now,
      end_time: 0,
      track: true,
      conditions: conditions,
      is_account_quest: account_quest?
    }

    Context.Quests.create_quest(quest_attrs)
  end

  @doc """
  Updates a quest's state to completed.

  ## Parameters
    * `quest` - The quest to complete

  ## Returns
    * `{:ok, updated_quest}` - Successfully completed quest
    * `{:error, changeset}` - Failed to update quest
  """
  def complete_quest(quest) do
    now = :os.system_time(:second)

    attrs = %{
      state: :completed,
      end_time: now,
      completion_count: quest.completion_count + 1
    }

    Context.Quests.update_quest(quest, attrs)
  end

  @doc """
  Updates a quest's state to abandoned.

  ## Parameters
    * `quest` - The quest to abandon

  ## Returns
    * `{:ok, updated_quest}` - Successfully abandoned quest
    * `{:error, changeset}` - Failed to update quest
  """
  def abandon_quest(quest) do
    attrs = %{
      state: :abandoned
    }

    Context.Quests.update_quest(quest, attrs)
  end

  @doc """
  Updates the tracking status of a quest.

  ## Parameters
    * `quest` - The quest to update
    * `tracking` - Boolean indicating whether to track the quest

  ## Returns
    * `{:ok, updated_quest}` - Successfully updated quest
    * `{:error, changeset}` - Failed to update quest
  """
  def update_tracking(quest, tracking) do
    Context.Quests.update_quest(quest, %{track: tracking})
  end

  @doc """
  Adds or updates a quest in the state map.

  ## Parameters
    * `quest` - The quest to add/update
    * `state` - The current state map

  ## Returns
    * Updated state map with the quest added/updated
  """
  def add_quest_to_state(quest, state) do
    if quest.is_account_quest do
      %{state | account_quests: Map.put(state.account_quests, quest.quest_id, quest)}
    else
      %{state | character_quests: Map.put(state.character_quests, quest.quest_id, quest)}
    end
  end

  @doc """
  Remove a quest from the state map.

  ## Parameters
    * `quest` - The quest to remove
    * `state` - The current state map

  ## Returns
    * Updated state map with the quest removed
  """
  def remove_quest_from_state(quest, state) do
    if quest.is_account_quest do
      %{state | account_quests: Map.delete(state.account_quests, quest.quest_id)}
    else
      %{state | character_quests: Map.delete(state.character_quests, quest.quest_id)}
    end
  end

  @doc """
  Gets all active quests from the state.

  ## Parameters
    * `state` - The current state map

  ## Returns
    * List of all active quests (both account and character quests)
  """
  def get_active_quests(state) do
    account_quests =
      state.account_quests
      |> Enum.filter(fn {_id, quest} -> quest.state == :started end)
      |> Enum.map(fn {_id, quest} -> quest end)

    character_quests =
      state.character_quests
      |> Enum.filter(fn {_id, quest} -> quest.state == :started end)
      |> Enum.map(fn {_id, quest} -> quest end)

    account_quests ++ character_quests
  end

  @doc """
  Gets a specific quest from the state.

  ## Parameters
    * `quest_id` - ID of the quest to retrieve
    * `state` - The current state map

  ## Returns
    * Quest struct if found, nil otherwise
  """
  def get_quest_from_state(quest_id, state) do
    quest = Map.get(state.character_quests, quest_id) || Map.get(state.account_quests, quest_id)

    if quest do
      # Add metadata if not already present
      if Map.has_key?(quest, :metadata) do
        quest
      else
        metadata = Storage.Quests.get_meta(quest.quest_id)
        %{quest | metadata: metadata}
      end
    else
      nil
    end
  end
end
