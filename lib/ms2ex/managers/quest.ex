defmodule Ms2ex.Managers.Quest do
  @moduledoc """
  GenServer to manage quest state for a character.

  This module handles quest state, progression tracking, condition checking,
  quest completion, and reward distribution.
  """

  use GenServer

  alias Ms2ex.{
    Context,
    Managers,
    Net,
    Packets,
    Storage,
    Types
  }

  require Logger

  # Constants
  @batch_size 20
  @default_timeout 5000

  # Client API

  @doc """
  Starts a quest manager for a character.
  """
  def start_link(character_id) do
    GenServer.start_link(__MODULE__, character_id, name: process_name(character_id))
  end

  @doc """
  Get all quests for a character, including both character-specific and account quests.
  Returns a tuple of {account_quests, character_quests}.
  """
  def get_all_quests(character_id) do
    GenServer.call(process_name(character_id), :get_all_quests, @default_timeout)
  end

  @doc """
  Get a quest by its ID.
  """
  def get_quest(character_id, quest_id) do
    GenServer.call(process_name(character_id), {:get_quest, quest_id}, @default_timeout)
  end

  @doc """
  Start a new quest for a character.
  """
  def start(quest_id, character) when is_integer(quest_id) do
    quest_metadata = Storage.Quests.get_meta(quest_id)

    if quest_metadata do
      GenServer.call(
        process_name(character.id),
        {:start_quest, quest_metadata, character},
        @default_timeout
      )
    else
      {:error, :quest_not_found}
    end
  end

  def start(character, quest_metadata) do
    GenServer.call(
      process_name(character.id),
      {:start_quest, quest_metadata, character},
      @default_timeout
    )
  end

  @doc """
  Complete a quest for a character.
  """
  def complete(quest_id, character_id) do
    GenServer.call(process_name(character_id), {:complete_quest, quest_id}, @default_timeout)
  end

  @doc """
  Abandon a quest.
  """
  def abandon(quest_id, character_id) do
    GenServer.call(process_name(character_id), {:abandon_quest, quest_id}, @default_timeout)
  end

  @doc """
  Update quest condition progress.
  """
  def update_conditions(
        character_id,
        condition_type,
        counter \\ 1,
        target_string \\ "",
        target_long \\ 0,
        code_string \\ "",
        code_long \\ 0
      ) do
    GenServer.cast(
      process_name(character_id),
      {:update_conditions, condition_type, counter, target_string, target_long, code_string,
       code_long}
    )
  end

  @doc """
  Update quest tracking status.
  """
  def update_tracking(quest_manager, quest_id, tracking) do
    GenServer.call(
      process_name(quest_manager.character_id),
      {:update_tracking, quest_id, tracking},
      @default_timeout
    )
  end

  @doc """
  Check if a character can start a quest.
  """
  def can_start?(character_id, quest_metadata) do
    GenServer.call(process_name(character_id), {:can_start, quest_metadata}, @default_timeout)
  end

  @doc """
  Check if a character can complete a quest.
  """
  def can_complete?(character_id, quest_id) do
    GenServer.call(process_name(character_id), {:can_complete, quest_id}, @default_timeout)
  end

  @doc """
  Get quests available from an NPC.
  """
  def get_available_quests(character_id, npc_id) do
    GenServer.call(process_name(character_id), {:get_available_quests, npc_id}, @default_timeout)
  end

  @doc """
  Get the quest manager's state.
  """
  def get_state(character_id) do
    GenServer.call(process_name(character_id), :get_state, @default_timeout)
  end

  @doc """
  Load quests for a character (called when a character enters the game).
  """
  def load_quests(session) do
    if pid = Process.whereis(process_name(session.character_id)) do
      GenServer.call(pid, {:load_quests, session}, @default_timeout)
    else
      {:ok, _pid} = start_link(session.character_id)

      GenServer.call(
        process_name(session.character_id),
        {:load_quests, session},
        @default_timeout
      )
    end
  end

  # Server callbacks

  @impl true
  def init(character) do
    {account_quests, character_quests} =
      Context.Quests.get_all_quests(character.account_id, character.id)

    state = %{
      account_quests: account_quests,
      character_quests: character_quests,
      character_id: character.id,
      account_id: character.account_id
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:get_all_quests, _from, state) do
    {:reply, {state.account_quests, state.character_quests}, state}
  end

  @impl true
  def handle_call({:get_quest, quest_id}, _from, state) do
    quest = Map.get(state.character_quests, quest_id) || Map.get(state.account_quests, quest_id)
    {:reply, quest, state}
  end

  @impl true
  def handle_call({:start_quest, quest_metadata, character}, _from, state) do
    # Check if quest already exists
    if Map.has_key?(state.character_quests, quest_metadata.id) or
         Map.has_key?(state.account_quests, quest_metadata.id) do
      {:reply, {:error, :quest_already_done}, state}
    else
      # Check if character can start quest
      if can_start_quest?(character, quest_metadata) do
        # Create quest
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

        case Context.Quests.create_quest(quest_attrs) do
          {:ok, quest} ->
            # Update state
            new_state =
              if account_quest? do
                %{state | account_quests: Map.put(state.account_quests, quest.quest_id, quest)}
              else
                %{
                  state
                  | character_quests: Map.put(state.character_quests, quest.quest_id, quest)
                }
              end

            # Handle quest accept rewards if any
            # TODO: Implement accept reward distribution

            # Send quest accept packet
            {:ok, character} = Character.lookup(state.character_id)

            if character.session_pid do
              quest_with_metadata = %{quest | metadata: quest_metadata}
              Ms2ex.Net.send(character.session_pid, Packets.Game.Quest.start(quest_with_metadata))
            end

            # Handle quest portal summoning if needed
            # TODO: Implement portal summoning

            {:reply, {:ok, quest}, new_state}

          {:error, changeset} ->
            Logger.error("Failed to create quest: #{inspect(changeset.errors)}")
            {:reply, {:error, :quest_accept_fail}, state}
        end
      else
        {:reply, {:error, :quest_accept_fail}, state}
      end
    end
  end

  @impl true
  def handle_call({:complete_quest, quest_id}, _from, state) do
    case get_quest_from_state(quest_id, state) do
      nil ->
        {:reply, {:error, :quest_not_found}, state}

      quest ->
        if quest.state == :completed do
          {:reply, {:error, :quest_already_done}, state}
        else
          # Check if all conditions are met
          if all_conditions_met?(quest) do
            # Update quest state
            now = :os.system_time(:second)

            attrs = %{
              state: :completed,
              end_time: now,
              completion_count: quest.completion_count + 1
            }

            case Context.Quests.update_quest(quest, attrs) do
              {:ok, updated_quest} ->
                # Update state
                new_state = update_quest_in_state(updated_quest, state)

                # Distribute rewards
                {:ok, character} = Managers.Character.lookup(state.character_id)
                distribute_rewards(character, quest)

                # Notify client
                if character.session_pid do
                  updated_quest_with_metadata = %{updated_quest | metadata: quest.metadata}

                  Ms2ex.Net.send(
                    character.session_pid,
                    Packets.Game.Quest.complete(updated_quest_with_metadata)
                  )
                end

                # Handle job advancement and chapter completion
                # TODO: Implement job advancement and chapter completion

                {:reply, {:ok, updated_quest}, new_state}

              {:error, changeset} ->
                Logger.error("Failed to complete quest: #{inspect(changeset.errors)}")
                {:reply, {:error, :quest_complete_fail}, state}
            end
          else
            {:reply, {:error, :quest_not_complete}, state}
          end
        end
    end
  end

  @impl true
  def handle_call({:abandon_quest, quest_id}, _from, state) do
    case get_quest_from_state(quest_id, state) do
      nil ->
        {:reply, {:error, :quest_not_found}, state}

      quest ->
        # Check if quest can be abandoned
        forfeitable = get_in(quest.metadata, [:basic, :forfeitable])

        if forfeitable == false do
          {:reply, {:error, :quest_abandon_restrict}, state}
        else
          # Delete quest
          owner_id = if quest.is_account_quest, do: state.account_id, else: state.character_id
          Context.Quests.delete_quest(owner_id, quest_id)

          # Update state
          new_state =
            if quest.is_account_quest do
              %{state | account_quests: Map.delete(state.account_quests, quest_id)}
            else
              %{state | character_quests: Map.delete(state.character_quests, quest_id)}
            end

          # Notify client
          {:ok, character} = Managers.Character.lookup(state.character_id)

          if character.session_pid do
            Ms2ex.Net.send(character.session_pid, Packets.Game.Quest.abandon(quest_id))
          end

          {:reply, {:ok, quest}, new_state}
        end
    end
  end

  @impl true
  def handle_call({:update_tracking, quest_id, tracking}, _from, state) do
    case get_quest_from_state(quest_id, state) do
      nil ->
        {:reply, {:error, :quest_not_found}, state}

      quest ->
        if quest.state == :completed do
          {:reply, {:error, :already_completed}, state}
        else
          case Context.Quests.update_quest(quest, %{track: tracking}) do
            {:ok, updated_quest} ->
              # Update state
              new_state = update_quest_in_state(updated_quest, state)

              # Notify client
              {:ok, character} = Managers.Character.lookup(state.character_id)

              if character.session_pid do
                Ms2ex.Net.send(
                  character.session_pid,
                  Packets.Game.Quest.set_tracking(quest_id, tracking)
                )
              end

              {:reply, {:ok, new_state}, new_state}

            {:error, changeset} ->
              Logger.error("Failed to update quest tracking: #{inspect(changeset.errors)}")
              {:reply, {:error, :update_failed}, state}
          end
        end
    end
  end

  @impl true
  def handle_call({:can_start, quest_metadata}, _from, state) do
    {:ok, character} = Managers.Character.lookup(state.character_id)
    result = can_start_quest?(character, quest_metadata)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:can_complete, quest_id}, _from, state) do
    case get_quest_from_state(quest_id, state) do
      nil -> {:reply, false, state}
      quest -> {:reply, all_conditions_met?(quest), state}
    end
  end

  @impl true
  def handle_call({:get_available_quests, npc_id}, _from, state) do
    {:ok, character} = Managers.Character.lookup(state.character_id)

    # Get quests that can be started from this NPC
    startable_quests =
      Storage.Quests.get_quests_by_npc(npc_id)
      |> Enum.filter(fn metadata ->
        quest_id = metadata.id

        not Map.has_key?(state.character_quests, quest_id) and
          not Map.has_key?(state.account_quests, quest_id) and
          can_start_quest?(character, metadata)
      end)

    # Get quests that can be completed at this NPC
    completable_quests =
      get_active_quests(state)
      |> Enum.filter(fn quest ->
        get_in(quest.metadata, [:basic, :complete_npc]) == npc_id and
          all_conditions_met?(quest)
      end)

    result = %{
      startable: startable_quests,
      completable: completable_quests
    }

    {:reply, result, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, {:ok, state}, state}
  end

  @impl true
  def handle_call({:load_quests, session}, _from, state) do
    # Send quest states to client
    send_quest_states(session, state)

    # Send exploration progress
    # TODO: Send exploration progress
    # Net.send(session.pid, Packets.Game.Quest.load_exploration(0))

    # Handle auto-start quests
    # TODO: Initialize auto-start quests

    {:reply, :ok, state}
  end

  @impl true
  def handle_cast(
        {:update_conditions, condition_type, counter, target_string, target_long, code_string,
         code_long},
        state
      ) do
    {:ok, character} = Managers.Character.lookup(state.character_id)

    # Get all active quests (both account and character quests)
    active_quests = get_active_quests(state)

    # Update conditions for matching quests
    updated_quests =
      active_quests
      |> Enum.reduce([], fn quest, acc ->
        updated =
          update_quest_conditions(
            quest,
            condition_type,
            character,
            counter,
            target_string,
            target_long,
            code_string,
            code_long
          )

        if updated != quest do
          # Save updated quest to database
          {:ok, saved_quest} =
            Context.Quests.update_quest(updated, %{conditions: updated.conditions})

          # Notify client of update
          if character.session_pid do
            Ms2ex.Net.send(character.session_pid, Packets.Game.Quest.update(saved_quest))
          end

          [saved_quest | acc]
        else
          acc
        end
      end)

    # Update state with updated quests
    new_state =
      Enum.reduce(updated_quests, state, fn quest, acc_state ->
        update_quest_in_state(quest, acc_state)
      end)

    # Check for auto-completion of quests (e.g., field missions)
    # TODO: Implement auto-completion for specific quest types

    {:noreply, new_state}
  end

  # Private functions

  defp process_name(character_id) do
    :"quest_manager:#{character_id}"
  end

  defp get_quest_from_state(quest_id, state) do
    quest = Map.get(state.character_quests, quest_id) || Map.get(state.account_quests, quest_id)

    if quest do
      metadata = Storage.Quests.get_meta(quest.quest_id)
      %{quest | metadata: metadata}
    else
      nil
    end
  end

  defp update_quest_in_state(quest, state) do
    if quest.is_account_quest do
      %{state | account_quests: Map.put(state.account_quests, quest.quest_id, quest)}
    else
      %{state | character_quests: Map.put(state.character_quests, quest.quest_id, quest)}
    end
  end

  defp get_active_quests(state) do
    character_active =
      state.character_quests
      |> Map.values()
      |> Enum.filter(&(&1.state != :completed))
      |> Enum.map(fn quest ->
        metadata = Storage.Quests.get_meta(quest.quest_id)
        %{quest | metadata: metadata}
      end)

    account_active =
      state.account_quests
      |> Map.values()
      |> Enum.filter(&(&1.state != :completed))
      |> Enum.map(fn quest ->
        metadata = Storage.Quests.get_meta(quest.quest_id)
        %{quest | metadata: metadata}
      end)

    character_active ++ account_active
  end

  defp can_start_quest?(_character, %{metadata: %{disabled: true}}) do
    false
  end

  defp can_start_quest?(character, metadata) do
    # Check if event tag is active
    # TODO: Check event tags

    Storage.Quests.meet_level_req?(character, metadata) &&
      Storage.Quests.meet_job_req?(character, metadata) &&
      Storage.Quests.meet_gear_score_req?(character, metadata) &&
      Storage.Quests.meet_achievement_req?(character, metadata) &&
      Storage.Quests.meet_selectable_quests_req?(character, metadata)
  end

  defp all_conditions_met?(quest) do
    Enum.all?(quest.conditions, fn {_idx, condition} ->
      condition.counter >= condition.metadata.value
    end)
  end

  defp update_quest_conditions(
         quest,
         condition_type,
         character,
         counter,
         target_string,
         target_long,
         code_string,
         code_long
       ) do
    # Filter conditions by type
    updated_conditions =
      quest.conditions
      |> Enum.reduce(quest.conditions, fn {idx, condition}, acc ->
        if condition.metadata.type == condition_type &&
             condition.counter < condition.metadata.value do
          # Check if condition matches the parameters
          if Types.Quest.Condition.check(
               condition_type,
               character,
               condition.metadata,
               target_string,
               target_long,
               code_string,
               code_long
             ) do
            # Update counter
            new_counter = min(condition.metadata.value, condition.counter + counter)
            Map.put(acc, idx, %{condition | counter: new_counter})
          else
            acc
          end
        else
          acc
        end
      end)

    # Return updated quest if conditions changed
    if updated_conditions == quest.conditions do
      quest
    else
      %{quest | conditions: updated_conditions}
    end
  end

  defp distribute_rewards(_character, quest) do
    metadata = quest.metadata
    reward = metadata.complete_reward

    # Experience
    if reward.exp && reward.exp > 0 do
      # TODO
      # Managers.Experience.add_exp(character.id, reward.exp)
    end

    # Mesos
    if reward.meso && reward.meso > 0 do
      # TODO
      # Managers.Currency.add_mesos(character.id, reward.meso)
    end

    # TODO: Add other currencies (treva, rue, etc.)

    # Add essential items
    if reward.essential_items && length(reward.essential_items) > 0 do
      Enum.each(reward.essential_items, fn _item ->
        nil
        # TODO: Create and add items to inventory
        # Item.add_item(character.id, item.id, item.amount, item.rarity)
      end)
    end

    # Add job items if they match character's job
    if reward.essential_job_items && length(reward.essential_job_items) > 0 do
      Enum.each(reward.essential_job_items, fn _item ->
        nil
        # TODO: Check job requirements and add items
        # if item matches job requirements:
        #   Managers.Item.add_item(character.id, item.id, item.amount, item.rarity)
      end)
    end

    # TODO: Handle selective items (items player can choose from)

    # TODO: Handle guild rewards
  end

  defp send_quest_states(session, state) do
    # Send character quests in batches
    state.character_quests
    |> Map.values()
    |> Enum.chunk_every(@batch_size)
    |> Enum.each(fn batch ->
      Net.send(session.pid, Packets.Game.Quest.load_quest_states(batch))
    end)

    # Send account quests in batches
    state.account_quests
    |> Map.values()
    |> Enum.chunk_every(@batch_size)
    |> Enum.each(fn batch ->
      Net.send(session.pid, Packets.Game.Quest.load_quest_states(batch))
    end)
  end
end
