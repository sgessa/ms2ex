defmodule Ms2ex.Managers.Quest do
  @moduledoc """
  GenServer to manage quest state for a character.

  This module handles quest state, progression tracking, condition checking,
  quest completion, and reward distribution.
  """

  use GenServer

  alias Ms2ex.{Context, Managers, Packets, Storage}
  import Ms2ex.Net.SenderSession, only: [push: 2]

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
  Get a specific quest by ID.
  """
  def get_quest(character_id, quest_id) do
    GenServer.call(process_name(character_id), {:get_quest, quest_id}, @default_timeout)
  end

  @doc """
  Starts a new quest for a character.
  """
  def start(character, quest_metadata) do
    GenServer.call(
      process_name(character.id),
      {:start_quest, quest_metadata, character},
      @default_timeout
    )
  end

  @doc """
  Completes a quest for a character.
  """
  def complete(quest_id, character_id) do
    GenServer.call(process_name(character_id), {:complete_quest, quest_id}, @default_timeout)
  end

  @doc """
  Abandons a quest for a character.
  """
  def abandon(quest_id, character_id) do
    GenServer.call(process_name(character_id), {:abandon_quest, quest_id}, @default_timeout)
  end

  @doc """
  Updates quest conditions based on character actions.
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
  Updates tracking status for a quest.
  """
  def update_tracking(character_id, quest_id, tracking) do
    GenServer.call(
      process_name(character_id),
      {:update_tracking, quest_id, tracking},
      @default_timeout
    )
  end

  @doc """
  Checks if a character can start a specific quest.
  """
  def can_start?(character_id, quest_metadata) do
    GenServer.call(process_name(character_id), {:can_start, quest_metadata}, @default_timeout)
  end

  @doc """
  Checks if a character can complete a specific quest.
  """
  def can_complete?(character_id, quest_id) do
    GenServer.call(process_name(character_id), {:can_complete, quest_id}, @default_timeout)
  end

  @doc """
  Gets quests available from a specific NPC.
  """
  def get_available_quests(character_id, npc_id) do
    GenServer.call(process_name(character_id), {:get_available_quests, npc_id}, @default_timeout)
  end

  @doc """
  Gets the current state of the quest manager.
  """
  def get_state(character_id) do
    GenServer.call(process_name(character_id), :get_state, @default_timeout)
  end

  @doc """
  Loads all quests for a character and sends to client.
  """
  def load_quests(session) do
    GenServer.call(
      process_name(session.character_id),
      {:load_quests, session},
      @default_timeout
    )
  end

  # Server Callbacks

  @impl true
  def init(character_id) do
    {:ok, character} = Managers.Character.lookup(character_id)

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

  #
  # GenServer Callbacks - handle_call
  #

  @impl true
  def handle_call(:get_all_quests, _from, state) do
    {:reply, {state.account_quests, state.character_quests}, state}
  end

  @impl true
  def handle_call({:get_quest, quest_id}, _from, state) do
    quest = Managers.Quest.State.get_quest_from_state(quest_id, state)
    {:reply, quest, state}
  end

  @impl true
  def handle_call({:start_quest, quest_metadata, character}, _from, state) do
    start_quest(quest_metadata, character, state)
  end

  @impl true
  def handle_call({:complete_quest, quest_id}, _from, state) do
    complete_quest(quest_id, state)
  end

  @impl true
  def handle_call({:abandon_quest, quest_id}, _from, state) do
    abandon_quest(quest_id, state)
  end

  @impl true
  def handle_call({:update_tracking, quest_id, tracking}, _from, state) do
    update_quest_tracking(quest_id, tracking, state)
  end

  @impl true
  def handle_call({:can_start, quest_metadata}, _from, state) do
    {:ok, character} = Managers.Character.lookup(state.character_id)
    result = Managers.Quest.Requirements.can_start?(character, quest_metadata, state)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:can_complete, quest_id}, _from, state) do
    case Managers.Quest.State.get_quest_from_state(quest_id, state) do
      nil -> {:reply, false, state}
      quest -> {:reply, Managers.Quest.Conditions.all_met?(quest), state}
    end
  end

  @impl true
  def handle_call({:get_available_quests, npc_id}, _from, state) do
    {:ok, character} = Managers.Character.lookup(state.character_id)

    # Get different types of quests and merge them
    all_quests = get_all_npc_quests(npc_id, character, state)

    {:reply, all_quests, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call({:load_quests, session}, _from, state) do
    # Send exploration data (placeholder until exploration system is implemented)
    push(session, Packets.Game.Quest.load_exploration(%{}))

    # Send quests in batches to avoid large packets
    state.account_quests
    |> Map.values()
    |> Enum.chunk_every(@batch_size)
    |> Enum.each(fn batch ->
      push(session, Packets.Game.Quest.load_quest_states(batch))
    end)

    state.character_quests
    |> Map.values()
    |> Enum.chunk_every(@batch_size)
    |> Enum.each(fn batch ->
      push(session, Packets.Game.Quest.load_quest_states(batch))
    end)

    {:reply, :ok, state}
  end

  # Helper functions for quest operations

  # Helper functions for start_quest
  defp start_quest(quest_metadata, character, state) do
    cond do
      quest_exists?(quest_metadata.id, state) ->
        {:reply, {:error, :quest_already_done}, state}

      not Managers.Quest.Requirements.can_start?(character, quest_metadata, state) ->
        {:reply, {:error, :quest_accept_fail}, state}

      true ->
        create_and_start_quest(quest_metadata, character, state)
    end
  end

  defp quest_exists?(quest_id, state) do
    Map.has_key?(state.character_quests, quest_id) or Map.has_key?(state.account_quests, quest_id)
  end

  defp create_and_start_quest(quest_metadata, character, state) do
    case Managers.Quest.State.create_quest(character, quest_metadata) do
      {:ok, quest} ->
        new_state = Managers.Quest.State.add_quest_to_state(quest, state)

        # Handle quest accept rewards if any
        Managers.Quest.Rewards.distribute_accept_rewards(character, quest_metadata)

        # Send quest accept packet
        if character.session_pid do
          quest_with_metadata = %{quest | metadata: quest_metadata}
          push(character, Packets.Game.Quest.start(quest_with_metadata))
        end

        # Handle quest portal summoning if needed
        # TODO: Implement portal summoning

        {:reply, {:ok, quest}, new_state}

      {:error, _changeset} ->
        {:reply, {:error, :quest_accept_fail}, state}
    end
  end

  # Helper functions for complete_quest
  defp complete_quest(quest_id, state) do
    case Managers.Quest.State.get_quest_from_state(quest_id, state) do
      nil ->
        {:reply, {:error, :quest_not_found}, state}

      quest ->
        process_quest_completion(quest, state)
    end
  end

  defp process_quest_completion(quest, state) do
    cond do
      quest.state == :completed ->
        {:reply, {:error, :quest_already_done}, state}

      not Managers.Quest.Conditions.all_met?(quest) ->
        {:reply, {:error, :quest_not_complete}, state}

      true ->
        finalize_quest_completion(quest, state)
    end
  end

  defp finalize_quest_completion(quest, state) do
    case Managers.Quest.State.complete_quest(quest) do
      {:ok, updated_quest} ->
        new_state = Managers.Quest.State.add_quest_to_state(updated_quest, state)

        # Distribute rewards
        {:ok, character} = Managers.Character.lookup(state.character_id)
        Managers.Quest.Rewards.distribute_completion_rewards(character, quest)

        # Notify client
        if character.session_pid do
          # Need to use the updated quest with metadata attached
          updated_quest_with_metadata = %{updated_quest | metadata: quest.metadata}
          push(character, Packets.Game.Quest.complete(updated_quest_with_metadata))
        end

        # Handle job advancement and chapter completion
        # TODO: Implement job advancement and chapter completion

        {:reply, {:ok, updated_quest}, new_state}

      {:error, _changeset} ->
        {:reply, {:error, :quest_complete_fail}, state}
    end
  end

  # Helper functions for abandon_quest
  defp abandon_quest(quest_id, state) do
    case Managers.Quest.State.get_quest_from_state(quest_id, state) do
      nil ->
        {:reply, {:error, :quest_not_found}, state}

      quest ->
        process_quest_abandonment(quest, state)
    end
  end

  defp process_quest_abandonment(quest, state) do
    if quest.state == :completed do
      {:reply, {:error, :quest_already_done}, state}
    else
      case Managers.Quest.State.abandon_quest(quest) do
        {:ok, updated_quest} ->
          # Update state by removing the quest
          new_state = Managers.Quest.State.remove_quest_from_state(updated_quest, state)

          # Notify client
          {:ok, character} = Managers.Character.lookup(state.character_id)

          if character.session_pid do
            push(character, Packets.Game.Quest.abandon(updated_quest.quest_id))
          end

          {:reply, {:ok, updated_quest}, new_state}

        {:error, _changeset} ->
          {:reply, {:error, :quest_abandon_fail}, state}
      end
    end
  end

  # Helper functions for update_tracking
  defp update_quest_tracking(quest_id, tracking, state) do
    case Managers.Quest.State.get_quest_from_state(quest_id, state) do
      nil ->
        {:reply, {:error, :quest_not_found}, state}

      quest ->
        process_tracking_update(quest, tracking, state)
    end
  end

  defp process_tracking_update(quest, tracking, state) do
    if quest.state != :started do
      {:reply, {:error, :quest_not_active}, state}
    else
      case Managers.Quest.State.update_tracking(quest, tracking) do
        {:ok, updated_quest} ->
          new_state = Managers.Quest.State.add_quest_to_state(updated_quest, state)

          # Notify client
          {:ok, character} = Managers.Character.lookup(state.character_id)

          if character.session_pid do
            push(
              character,
              Packets.Game.Quest.set_tracking(updated_quest.quest_id, updated_quest.track)
            )
          end

          {:reply, {:ok, updated_quest}, new_state}

        {:error, _changeset} ->
          {:reply, {:error, :quest_update_fail}, state}
      end
    end
  end

  # Helper functions for get_available_quests
  defp get_all_npc_quests(npc_id, character, state) do
    available_quests = get_available_new_quests(npc_id, character, state)
    in_progress_quests = get_completable_character_quests(npc_id, state)
    account_quests = get_completable_account_quests(npc_id, state)

    # Merge all quest types
    Map.merge(available_quests, Map.merge(in_progress_quests, account_quests))
  end

  defp get_available_new_quests(npc_id, character, state) do
    Storage.Quests.get_quests_by_npc(npc_id)
    |> Enum.filter(fn quest_metadata ->
      # Check if quest is already done or in progress
      not Map.has_key?(state.character_quests, quest_metadata.id) and
        not Map.has_key?(state.account_quests, quest_metadata.id) and
        Managers.Quest.Requirements.can_start?(character, quest_metadata, state)
    end)
    |> Enum.map(fn quest_metadata -> {quest_metadata.id, quest_metadata} end)
    |> Enum.into(%{})
  end

  defp get_completable_character_quests(npc_id, state) do
    state.character_quests
    |> Enum.filter(fn {_id, quest} ->
      quest.state == :started and
        quest.metadata.basic.complete_npc == npc_id and
        Managers.Quest.Conditions.all_met?(quest)
    end)
    |> Enum.map(fn {id, quest} -> {id, quest.metadata} end)
    |> Enum.into(%{})
  end

  defp get_completable_account_quests(npc_id, state) do
    state.account_quests
    |> Enum.filter(fn {_id, quest} ->
      quest.state == :started and
        quest.metadata.basic.complete_npc == npc_id and
        Managers.Quest.Conditions.all_met?(quest)
    end)
    |> Enum.map(fn {id, quest} -> {id, quest.metadata} end)
    |> Enum.into(%{})
  end

  @impl true
  def handle_cast(
        {:update_conditions, condition_type, counter, target_string, target_long, code_string,
         code_long},
        state
      ) do
    # Get character for sending packets
    {:ok, character} = Managers.Character.lookup(state.character_id)

    # Process character and account quests
    {updated_character_quests, character_updated} =
      update_quest_conditions(
        state.character_quests,
        character,
        condition_type,
        counter,
        target_string,
        target_long,
        code_string,
        code_long
      )

    {updated_account_quests, account_updated} =
      update_quest_conditions(
        state.account_quests,
        character,
        condition_type,
        counter,
        target_string,
        target_long,
        code_string,
        code_long
      )

    # Only update state if any quests were actually updated
    if character_updated || account_updated do
      new_state = %{
        state
        | character_quests: updated_character_quests,
          account_quests: updated_account_quests
      }

      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  # Helper function to update conditions for a set of quests
  defp update_quest_conditions(
         quests,
         character,
         condition_type,
         counter,
         target_string,
         target_long,
         code_string,
         code_long
       ) do
    Enum.reduce(quests, {quests, false}, fn {quest_id, quest}, {acc_quests, any_updated} ->
      updated_quest =
        Managers.Quest.Conditions.update(
          quest,
          condition_type,
          counter,
          target_string,
          target_long,
          code_string,
          code_long
        )

      if updated_quest != quest do
        # Send update packet to client
        if character.session_pid do
          push(character, Packets.Game.Quest.update(updated_quest))
        end

        # Auto-complete field missions if all conditions are met
        handle_auto_completion(updated_quest, character.id)

        {Map.put(acc_quests, quest_id, updated_quest), true}
      else
        {acc_quests, any_updated}
      end
    end)
  end

  # Helper function to handle auto-completion of field missions
  defp handle_auto_completion(quest, character_id) do
    if quest.metadata.basic.type == :field_mission &&
         Managers.Quest.Conditions.all_met?(quest) do
      # Complete the quest in a separate call to handle rewards properly
      # This is async and non-blocking
      spawn(fn ->
        complete(quest.quest_id, character_id)
      end)
    end
  end

  defp process_name(character_id) do
    :"quest_manager:#{character_id}"
  end
end
