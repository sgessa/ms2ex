defmodule Ms2ex.Managers.Quest do
  @moduledoc """
  GenServer to manage quest state for a character.

  This module handles quest state, progression tracking, condition checking,
  quest completion, and reward distribution.
  """

  use GenServer

  alias Ms2ex.Context
  alias Ms2ex.Managers
  alias Ms2ex.Packets
  alias Ms2ex.Repo
  alias Ms2ex.Storage
  import Ms2ex.Net.SenderSession, only: [push: 2]

  # Constants
  @batch_size 200
  @default_timeout 5000
  @throttled_conditions [:fall, :swim, :swimtime, :run, :stay_cube, :crawl, :glide, :climb, :ropetime, :laddertime, :holdtime, :riding, :emotiontime]

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
  Removes the given quests from the character (expiration sweep from the
  client) and drops their persisted rows.
  """
  def expire_quests(character_id, quest_ids) do
    GenServer.call(process_name(character_id), {:expire_quests, quest_ids}, @default_timeout)
  end

  @doc """
  Moves the character to a started quest's go-to-npc destination map.
  """
  def go_to_npc(character_id, quest_id) do
    GenServer.call(process_name(character_id), {:go_to_npc, quest_id}, @default_timeout)
  end

  @doc """
  Moves the character to a quest's dispatch destination (the "do you want to
  travel?" prompt from quest dialogues).
  """
  def dispatch(character_id, quest_id) do
    GenServer.call(process_name(character_id), {:dispatch, quest_id}, @default_timeout)
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

    {:ok, initialize_auto_start_quests(character, state)}
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
  def handle_call({:expire_quests, quest_ids}, _from, state) do
    {new_state, removed_ids} =
      Enum.reduce(quest_ids, {state, []}, fn quest_id, {acc_state, removed} ->
        case expire_quest(quest_id, acc_state) do
          {acc_state, quest_id} when is_integer(quest_id) -> {acc_state, [quest_id | removed]}
          {acc_state, nil} -> {acc_state, removed}
        end
      end)

    removed_ids = Enum.reverse(removed_ids)

    with {:ok, character} <- Managers.Character.lookup(state.character_id),
         true <- character.session_pid != nil do
      push(character, Packets.Game.Quest.expired(removed_ids))
    end

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:go_to_npc, quest_id}, _from, state) do
    reply =
      case Managers.Quest.State.get_quest_from_state(quest_id, state) do
        %{metadata: %{go_to_npc: %{enabled: true, map_id: map_id}}} ->
          {:ok, character} = Managers.Character.lookup(state.character_id)
          Context.Field.change_field(character, map_id)

        _ ->
          :ok
      end

    {:reply, reply, state}
  end

  @impl true
  def handle_call({:dispatch, quest_id}, _from, state) do
    reply =
      case Managers.Quest.State.get_quest_from_state(quest_id, state) do
        %{state: quest_state, metadata: %{dispatch: %{map_id: map_id}}}
        when quest_state != :completed and map_id > 0 ->
          {:ok, character} = Managers.Character.lookup(state.character_id)
          Context.Field.change_field(character, map_id)

        _ ->
          :ok
      end

    {:reply, reply, state}
  end

  @impl true
  def handle_call({:load_quests, session}, _from, state) do
    push(session, Packets.Game.Quest.load_exploration(exploration_progress(state)))

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
    # accept rewards are granted in the same transaction as the quest row so
    # a failing grant cannot leave a started quest without its items
    rewards = Managers.Quest.Rewards.prepare(character, quest_metadata.accept_reward)

    transaction =
      Repo.transaction(fn ->
        with {:ok, quest} <- Managers.Quest.State.create_quest(character, quest_metadata),
             {:ok, results} <- Managers.Quest.Rewards.grant_items(character, rewards) do
          {quest, results}
        else
          {:error, reason} -> Repo.rollback(reason)
        end
      end)

    handle_accept_result(transaction, quest_metadata, character, state)
  end

  defp handle_accept_result(transaction, quest_metadata, character, state) do
    case transaction do
      {:ok, {quest, results}} ->
        new_state = Managers.Quest.State.add_quest_to_state(quest, state)

        Managers.Quest.Rewards.deliver(character, quest_metadata.accept_reward, results)
        update_conditions(character.id, :quest_accept, 1, "", 0, "", quest_metadata.id)
        maybe_push_quest_start(character, quest, quest_metadata)

        # TODO: Implement portal summoning

        {:reply, {:ok, quest}, new_state}

      {:error, _reason} ->
        {:reply, {:error, :quest_accept_fail}, state}
    end
  end

  defp maybe_push_quest_start(character, quest, quest_metadata) do
    if character.session_pid do
      quest_with_metadata = %{quest | metadata: quest_metadata}
      push(character, Packets.Game.Quest.start(quest_with_metadata))
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
    {:ok, character} = Managers.Character.lookup(state.character_id)

    # completion, turn-in item consumption and item rewards commit atomically;
    # experience and currencies are delivered post-commit (exp lives in the
    # character manager's state)
    rewards = Managers.Quest.Rewards.prepare(character, quest.metadata.complete_reward)
    consumables = quest_consumables(quest)

    transaction =
      Repo.transaction(fn ->
        with {:ok, consume_results} <-
               Context.Inventory.consume_item_amounts(character, consumables),
             {:ok, updated_quest} <- Managers.Quest.State.complete_quest(quest),
             {:ok, results} <- Managers.Quest.Rewards.grant_items(character, rewards) do
          {updated_quest, consume_results, results}
        else
          {:error, reason} -> Repo.rollback(reason)
        end
      end)

    handle_completion_result(transaction, quest, character, state)
  end

  defp handle_completion_result(transaction, quest, character, state) do
    case transaction do
      {:ok, {updated_quest, consume_results, results}} ->
        new_state = Managers.Quest.State.add_quest_to_state(updated_quest, state)

        Managers.Quest.Rewards.deliver(character, quest.metadata.complete_reward, results)
        Enum.each(consume_results, &maybe_push_consume(character, &1))

        update_conditions(
          character.id,
          :quest_clear_by_chapter,
          1,
          "",
          0,
          "",
          quest.metadata.basic.chapter_id
        )

        update_conditions(character.id, :quest, 1, "", 0, "", quest.metadata.id)
        update_conditions(character.id, :quest_clear, 1, "", 0, "", quest.metadata.id)

        if quest.metadata.basic.type == :field_mission do
          update_conditions(character.id, :field_mission, 1, "", 0, "", quest.metadata.id)
          handle_exploration_completion(character, state, new_state)
        end

        maybe_push_quest_complete(character, updated_quest, quest.metadata)

        # TODO: Implement job advancement and chapter completion

        {:reply, {:ok, updated_quest}, new_state}

      {:error, _reason} ->
        {:reply, {:error, :quest_complete_fail}, state}
    end
  end

  defp maybe_push_quest_complete(character, updated_quest, quest_metadata) do
    if character.session_pid do
      updated_quest_with_metadata = %{updated_quest | metadata: quest_metadata}
      push(character, Packets.Game.Quest.complete(updated_quest_with_metadata))
    end
  end

  defp handle_exploration_completion(character, state, new_state) do
    progress = exploration_progress(state)
    new_progress = exploration_progress(new_state)

    if new_progress > progress do
      push_exploration_progress(character, new_progress)
      award_exploration_reward(character, new_progress)
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

  defp process_quest_abandonment(%{state: :completed}, state) do
    {:reply, {:error, :quest_already_done}, state}
  end

  defp process_quest_abandonment(%{metadata: %{basic: %{forfeitable: false}}}, state) do
    {:reply, {:error, :quest_abandon_restrict}, state}
  end

  defp process_quest_abandonment(quest, state) do
    case Managers.Quest.State.abandon_quest(quest) do
      {:ok, updated_quest} ->
        Context.Quests.delete_quest(
          updated_quest.owner_id,
          updated_quest.quest_id,
          updated_quest.is_account_quest
        )

        new_state = Managers.Quest.State.remove_quest_from_state(updated_quest, state)
        {:ok, character} = Managers.Character.lookup(state.character_id)
        maybe_push_abandon(character, updated_quest.quest_id)
        {:reply, {:ok, updated_quest}, new_state}

      {:error, _changeset} ->
        {:reply, {:error, :quest_abandon_fail}, state}
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

  defp process_tracking_update(%{state: state}, _tracking, current_state)
       when state != :started do
    {:reply, {:error, :quest_not_active}, current_state}
  end

  defp process_tracking_update(quest, tracking, state) do
    case Managers.Quest.State.update_tracking(quest, tracking) do
      {:ok, updated_quest} ->
        new_state = Managers.Quest.State.add_quest_to_state(updated_quest, state)
        {:ok, character} = Managers.Character.lookup(state.character_id)
        maybe_push_tracking(character, updated_quest)
        {:reply, {:ok, updated_quest}, new_state}

      {:error, _changeset} ->
        {:reply, {:error, :quest_update_fail}, state}
    end
  end

  # Helper functions for get_available_quests
  defp get_all_npc_quests(npc_id, character, state) do
    available_quests = get_available_new_quests(npc_id, character, state)
    in_progress_quests = get_active_character_quests(npc_id, state)
    account_quests = get_active_account_quests(npc_id, state)

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

  defp get_active_character_quests(npc_id, state) do
    active_npc_quests(state.character_quests, npc_id)
  end

  defp get_active_account_quests(npc_id, state) do
    active_npc_quests(state.account_quests, npc_id)
  end

  defp active_npc_quests(quests, npc_id) do
    quests
    |> Enum.filter(fn {_id, quest} ->
      quest.state == :started and quest.metadata.basic.complete_npc == npc_id
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

    Context.Achievements.progress(
      character,
      condition_type,
      counter,
      target_string,
      target_long,
      code_string,
      code_long
    )

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
      case update_single_quest_condition(
             quest,
             character,
             condition_type,
             counter,
             target_string,
             target_long,
             code_string,
             code_long
           ) do
        {:updated, updated_quest} ->
          {Map.put(acc_quests, quest_id, updated_quest), true}

        :unchanged ->
          {acc_quests, any_updated}
      end
    end)
  end

  defp update_single_quest_condition(
         quest,
         character,
         condition_type,
         counter,
         target_string,
         target_long,
         code_string,
         code_long
       ) do
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

    if updated_quest == quest do
      :unchanged
    else
      case Context.Quests.update_quest(updated_quest, %{conditions: updated_quest.conditions}) do
        {:ok, persisted_quest} ->
          maybe_push_condition_update(character, quest, persisted_quest, condition_type)
          handle_auto_completion(persisted_quest, character.id)
          {:updated, persisted_quest}

        {:error, _changeset} ->
          # keep gameplay moving on the in-memory state even if the write fails
          maybe_push_condition_update(character, quest, updated_quest, condition_type)
          {:updated, updated_quest}
      end
    end
  end

  defp maybe_push_update(%{session_pid: nil}, _quest), do: :ok
  defp maybe_push_update(character, quest), do: push(character, Packets.Game.Quest.update(quest))

  defp maybe_push_condition_update(character, previous_quest, quest, condition_type)
       when condition_type in @throttled_conditions do
    if condition_bucket(quest) > condition_bucket(previous_quest) or
         Managers.Quest.Conditions.all_met?(quest) do
      maybe_push_update(character, quest)
    end
  end

  defp maybe_push_condition_update(character, _previous_quest, quest, _condition_type),
    do: maybe_push_update(character, quest)

  defp condition_bucket(quest) do
    quest.conditions
    |> Map.values()
    |> Enum.map(&div(&1.counter, 5))
    |> Enum.max(fn -> 0 end)
  end

  defp maybe_push_tracking(%{session_pid: nil}, _quest), do: :ok

  defp maybe_push_tracking(character, quest) do
    push(character, Packets.Game.Quest.set_tracking(quest.quest_id, quest.track))
  end

  defp maybe_push_abandon(%{session_pid: nil}, _quest_id), do: :ok

  defp maybe_push_abandon(character, quest_id),
    do: push(character, Packets.Game.Quest.abandon(quest_id))

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

  defp push_exploration_progress(%{session_pid: nil}, _progress), do: :ok

  defp push_exploration_progress(character, progress) do
    push(character, Packets.Game.Quest.update_exploration(progress))
  end

  defp exploration_progress(state) do
    [state.account_quests, state.character_quests]
    |> Enum.flat_map(&Map.values/1)
    |> Enum.count(&(&1.state == :completed and &1.metadata.basic.type == :field_mission))
    |> Ms2ex.Storage.Tables.FieldMission.reached_progress()
  end

  defp award_exploration_reward(character, progress) do
    case Ms2ex.Storage.Tables.FieldMission.get(progress) do
      %{item: %{id: item_id, amount: amount, rarity: rarity}} when item_id > 0 and amount > 0 ->
        item = Context.Items.init(item_id, %{amount: amount, rarity: rarity})

        case Context.Inventory.add_item(character, item) do
          {:ok, result} -> push(character, Packets.InventoryItem.add_item(result, character))
          _ -> :ok
        end

      %{stat_points: stat_points} when stat_points > 0 ->
        Managers.Character.StatPoints.add_stat_point(character, :exploration, stat_points)

      _ ->
        :ok
    end
  end

  defp initialize_auto_start_quests(character, state) do
    Storage.Quests.auto_start_quests()
    |> Enum.reduce(state, fn quest_metadata, acc ->
      maybe_auto_start_quest(character, acc, quest_metadata)
    end)
  end

  defp maybe_auto_start_quest(character, state, quest_metadata) do
    if skip_auto_start?(character, state, quest_metadata) do
      state
    else
      case Managers.Quest.State.create_quest(character, quest_metadata) do
        {:ok, quest} ->
          announce_auto_start(character, quest, quest_metadata)
          Managers.Quest.State.add_quest_to_state(quest, state)

        {:error, _changeset} ->
          state
      end
    end
  end

  # auto-started quests never went through the accept flow, so the client
  # learns about them from a Start frame (before the state list loads)
  defp announce_auto_start(character, quest, quest_metadata) do
    if character.session_pid do
      quest_with_metadata = %{quest | metadata: quest_metadata}
      push(character, Packets.Game.Quest.start(quest_with_metadata))
    end
  end

  defp skip_auto_start?(character, state, quest_metadata) do
    quest_exists?(quest_metadata.id, state) or
      quest_metadata.event_mission_type != :none or
      quest_metadata.basic.type == :field_mission or
      quest_metadata.basic.complete_npc > 0 or
      quest_metadata.basic.complete_maps != [] or
      not Managers.Quest.Requirements.can_start?(character, quest_metadata, state)
  end

  # turn-in items: item_exist conditions name the item and required amount;
  # the held amount is consumed when the quest completes
  defp quest_consumables(quest) do
    Enum.flat_map(quest.conditions, fn {_index, condition} ->
      case condition do
        %{metadata: %{type: :item_exist, value: value, codes: %{integers: [item_id | _]}}}
        when is_integer(item_id) and item_id > 0 and value > 0 ->
          [%{item_id: item_id, amount: value}]

        _ ->
          []
      end
    end)
  end

  defp maybe_push_consume(%{session_pid: nil}, _result), do: :ok

  defp maybe_push_consume(character, result) do
    push(character, Packets.InventoryItem.consume(result))
  end

  defp expire_quest(quest_id, state) do
    case Managers.Quest.State.get_quest_from_state(quest_id, state) do
      nil ->
        {state, nil}

      quest ->
        Context.Quests.delete_quest(quest.owner_id, quest.quest_id, quest.is_account_quest)
        {Managers.Quest.State.remove_quest_from_state(quest, state), quest_id}
    end
  end

  defp process_name(character_id) do
    :"quest_manager:#{character_id}"
  end
end
