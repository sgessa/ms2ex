defmodule Ms2ex.Managers.Quest.Rewards do
  @moduledoc """
  Functions for distributing quest rewards.

  This module handles reward distribution for both quest acceptance and completion.
  It manages experience, mesos, items, and other currencies that are granted to players.
  """

  alias Ms2ex.Managers

  @doc """
  Distributes rewards when accepting a quest.

  ## Parameters
    * `character` - The character to receive rewards
    * `quest_metadata` - The quest metadata containing reward information

  ## Returns
    * `:ok` - Successfully distributed rewards
  """
  def distribute_accept_rewards(character, quest_metadata) do
    reward = quest_metadata.accept_reward

    # Handle essential items
    if reward.essential_items && length(reward.essential_items) > 0 do
      # Enum.each(reward.essential_items, fn item ->

      # TODO: Add implementation for item creation and distribution
      # Create item and add to inventory, similar to C# implementation:
      # Item? reward = session.Field.ItemDrop.CreateItem(acceptReward.Id, acceptReward.Rarity, acceptReward.Amount);
      # session.Item.Inventory.Add(reward, true)
      # end)
      :ok
    end

    # Handle job items if applicable
    if reward.essential_job_items && length(reward.essential_job_items) > 0 do
      job_items = filter_job_items(character, reward.essential_job_items)
      distribute_items(character, job_items)
    end

    :ok
  end

  @doc """
  Distributes rewards when completing a quest.

  ## Parameters
    * `character` - The character to receive rewards
    * `quest` - The completed quest with metadata

  ## Returns
    * `:ok` - Successfully distributed rewards
  """
  def distribute_completion_rewards(character, quest) do
    metadata = quest.metadata
    reward = metadata.complete_reward

    # Experience
    if reward.exp && reward.exp > 0 do
      Managers.Character.cast(character.id, {:earn_exp, reward.exp})
    end

    # Mesos
    if reward.meso && reward.meso > 0 do
      # TODO: Add implementation for adding mesos
      # Managers.Currency.add_mesos(character.id, reward.meso)
    end

    # Other currencies
    distribute_currencies(character, reward)

    # Add essential items
    if reward.essential_items && length(reward.essential_items) > 0 do
      distribute_items(character, reward.essential_items)
    end

    # Add job items if they match character's job
    if reward.essential_job_items && length(reward.essential_job_items) > 0 do
      # Filter items based on character job
      job_items = filter_job_items(character, reward.essential_job_items)
      distribute_items(character, job_items)
    end

    # Handle selective items (items player can choose from)
    if reward.selective_items && length(reward.selective_items) > 0 do
      # TODO: Implement selective item UI and handling
    end

    :ok
  end

  defp distribute_items(_character, _items) do
    # Enum.each(items, fn item ->

    # TODO: Add implementation for item creation and adding to inventory

    # 1. Create item
    # item = create_item(item.id, item.rarity, item.amount)
    #
    # 2. Try to add to inventory, fallback to mail
    # if !can_add_to_inventory(character, item) do
    #   send_item_to_mail(character, item)
    # else
    #   add_item_to_inventory(character, item)
    # end
    # end)

    :ok
  end

  defp filter_job_items(_character, _items) do
    # Filter items based on character's job

    # Enum.filter(items, fn item ->
    # TODO: Add proper job filtering logic
    # 1. Get item metadata
    # 2. Check if job_recommends includes character's job or is empty
    # Temporary - return all items until job filtering is implemented
    # true
    # end)
  end

  defp distribute_currencies(_character, _reward) do
    # Handle additional currencies like treva, rue, etc.
    # Example:
    # if reward.treva && reward.treva > 0 do
    #   Managers.Currency.add(character.id, :treva, reward.treva)
    # end
    #
    # if reward.rue && reward.rue > 0 do
    #   Managers.Currency.add(character.id, :rue, reward.rue)
    # end

    :ok
  end
end
