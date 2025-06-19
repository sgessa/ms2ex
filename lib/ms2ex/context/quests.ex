defmodule Ms2ex.Context.Quests do
  @moduledoc """
  Context module for handling quest-related database operations.
  """

  import Ecto.Query

  alias Ms2ex.{Repo, Schema, Storage}
  alias Ms2ex.Schema.CharacterQuest

  @doc """
  Gets all quests for an account and character.
  Returns a tuple with {account_quests, character_quests} where each is a map of quest_id to quest data.
  """
  @spec get_all_quests(binary(), binary()) :: {map(), map()}
  def get_all_quests(account_id, character_id) do
    CharacterQuest
    |> where(
      [q],
      (q.owner_id == ^account_id and q.is_account_quest == true) or q.owner_id == ^character_id
    )
    |> Repo.all()
    |> Enum.reduce({%{}, %{}}, fn quest, {account_quests, character_quests} ->
      metadata = Storage.Quests.get_meta(quest.quest_id)
      enhanced_quest = %{quest | metadata: metadata}

      if quest.is_account_quest do
        {Map.put(account_quests, quest.quest_id, enhanced_quest), character_quests}
      else
        {account_quests, Map.put(character_quests, quest.quest_id, enhanced_quest)}
      end
    end)
  end

  @doc """
  Creates a new quest.

  ## Parameters
    * `attrs` - Map with the following keys:
      * `:owner_id` - Binary ID of the owner (character or account)
      * `:quest_id` - Integer ID of the quest
      * `:state` - Quest state atom (e.g., :started, :completed)
      * `:start_time` - Integer timestamp when quest was started
      * `:track` - Boolean whether quest is being tracked
      * `:conditions` - Map of quest conditions
      * `:is_account_quest` - Boolean whether quest belongs to account or character
      * `:completion_count` - Optional, integer count of completions (default: 0)
      * `:end_time` - Optional, integer timestamp when quest was completed (default: 0)
  """
  @spec create_quest(map()) :: {:ok, CharacterQuest.t()} | {:error, Ecto.Changeset.t()}
  def create_quest(attrs) do
    attrs = Map.merge(%{completion_count: 0, end_time: 0}, attrs)

    %CharacterQuest{}
    |> CharacterQuest.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an existing quest.

  ## Parameters
    * `quest` - The quest struct to update
    * `attrs` - Map with the attributes to update, such as:
      * `:state` - Quest state atom (e.g., :started, :completed)
      * `:completion_count` - Integer count of quest completions
      * `:end_time` - Integer timestamp when quest was completed
      * `:track` - Boolean whether quest is being tracked
      * `:conditions` - Map of quest conditions
  """
  @spec update_quest(CharacterQuest.t(), map()) ::
          {:ok, CharacterQuest.t()} | {:error, Ecto.Changeset.t()}
  def update_quest(quest, attrs) do
    quest
    |> CharacterQuest.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a quest by owner ID and quest ID.
  """
  @spec delete_quest(binary(), integer()) :: :ok
  def delete_quest(owner_id, quest_id) do
    CharacterQuest
    |> where([q], q.owner_id == ^owner_id and q.quest_id == ^quest_id)
    |> Repo.delete_all()

    :ok
  end

  @doc """
  Checks if an owner has completed a quest.
  """
  @spec has_completed_quest?(Schema.Character.t(), integer()) :: boolean()
  def has_completed_quest?(character, quest_id) do
    quest = Storage.Quests.get_meta(quest_id)
    account_quest? = Storage.Quests.account_quest?(quest)
    owner_id = Storage.Quests.get_owner_id(character, quest)

    CharacterQuest
    |> where([q], q.owner_id == ^owner_id)
    |> where([q], q.quest_id == ^quest.id)
    |> where([q], q.state == :completed)
    |> where([q], q.is_account_quest == ^account_quest?)
    |> limit(1)
    |> Repo.one()
    |> is_nil()
    |> Kernel.not()
  end
end
