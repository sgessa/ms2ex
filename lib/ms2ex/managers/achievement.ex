defmodule Ms2ex.Managers.Achievement do
  use GenServer
  use Ms2ex.Managers.Managed, prefix: "achievements", key: :character_id

  alias Ms2ex.Context
  alias Ms2ex.Managers
  alias Ms2ex.Managers.Quest.Conditions
  alias Ms2ex.Packets
  alias Ms2ex.Schema
  alias Ms2ex.Storage

  import Ms2ex.Net.SenderSession, only: [push: 2]

  @load_batch_size 60
  @flush_interval :timer.minutes(1)

  # The achievement manager keeps every achievement row of a character (and
  # of its account) in memory: condition checks walk the storage index and
  # never touch the database, new rows are inserted the moment they are
  # created, and updates to existing rows are batched and flushed
  # periodically and on disconnect. Rows are kept without their metadata
  # documents; metadata is read from the storage cache at point of use.

  def start(%Schema.Character{id: id} = character) do
    case Managers.ManagerSupervisor.start_child(__MODULE__, character, process_name(id)) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      error -> error
    end
  end

  @doc false
  def start_link(%Schema.Character{} = character) do
    GenServer.start_link(__MODULE__, character, name: process_name(character.id))
  end

  def stop(%Schema.Character{id: id}), do: stop(id)

  def stop(id) when is_integer(id) do
    case Process.whereis(process_name(id)) do
      nil -> :ok
      pid -> Managers.ManagerSupervisor.terminate_child(pid)
    end
  end

  # ---- client API ----

  @doc """
  Sends the achievement initialize and load packets, batched per
  #{@load_batch_size} entries.
  """
  def load(%Schema.Character{id: id}), do: call(id, :load)

  @doc """
  Advances every achievement whose active grade condition matches the
  event. Fire-and-forget: progress is applied asynchronously.
  """
  def update(
        character_id,
        condition_type,
        counter \\ 1,
        target_string \\ "",
        target_long \\ 0,
        code_string \\ "",
        code_long \\ 0
      )

  def update(
        character_id,
        condition_type,
        counter,
        target_string,
        target_long,
        code_string,
        code_long
      ) do
    cast(
      character_id,
      {:update, condition_type, counter, target_string, target_long, code_string, code_long}
    )
  end

  @doc "Trophy counts per category: [combat, adventure, lifestyle]."
  def trophy_counts(%Schema.Character{id: id}), do: call(id, :trophy_counts)

  @doc "Persists every pending achievement update."
  def flush(%Schema.Character{id: id}), do: call(id, :flush)

  @doc "Claims every pending reward grade up to the current grade."
  def claim_reward(%Schema.Character{id: id}, achievement_id),
    do: call(id, {:claim_reward, achievement_id})

  def toggle_favorite(%Schema.Character{id: id}, achievement_id, favorite),
    do: call(id, {:toggle_favorite, achievement_id, favorite})

  # ---- Server Callbacks ----

  @impl true
  def init(%Schema.Character{} = character) do
    # deferred writes are flushed in terminate, which only runs on the
    # teardown shutdown signal when exits are trapped
    Process.flag(:trap_exit, true)

    achievements =
      [character.account_id, character.id]
      |> Enum.uniq()
      |> Enum.reject(&is_nil/1)
      |> Enum.flat_map(&Context.Achievements.list/1)
      |> Map.new(&{&1.achievement_id, &1})

    state = %{
      character_id: character.id,
      account_id: character.account_id,
      achievements: achievements,
      trophies: count_trophies(achievements),
      dirty: MapSet.new()
    }

    Process.send_after(self(), :flush, @flush_interval)
    {:ok, state}
  end

  @impl true
  def handle_call(:load, _from, state) do
    {:ok, character} = Managers.Character.lookup(state.character_id)

    if character.session_pid do
      push(character, Packets.Achievement.initialize())

      state.achievements
      |> Map.values()
      |> Enum.sort_by(& &1.achievement_id)
      |> Enum.map(&Map.put(&1, :metadata, Storage.Achievements.get(&1.achievement_id)))
      |> Enum.reject(&is_nil(&1.metadata))
      |> Enum.chunk_every(@load_batch_size)
      |> Enum.each(&push(character, Packets.Achievement.load(&1)))
    end

    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:trophy_counts, _from, state), do: {:reply, state.trophies, state}

  @impl true
  def handle_call(:flush, _from, state), do: {:reply, :ok, flush_dirty(state)}

  @impl true
  def handle_call({:claim_reward, achievement_id}, _from, state) do
    {:ok, character} = Managers.Character.lookup(state.character_id)
    metadata = Storage.Achievements.get(achievement_id)

    state =
      with {:ok, achievement} <- fetch(state, achievement_id),
           false <- is_nil(metadata) do
        achievement =
          Enum.reduce(
            achievement.reward_grade..achievement.current_grade//1,
            achievement,
            fn _grade, achievement ->
              {:ok, achievement} = give_reward(achievement, metadata, character, true)
              maybe_push_update(character, achievement, metadata)
              achievement
            end
          )

        put_achievement(state, achievement)
      else
        _ -> state
      end

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:toggle_favorite, achievement_id, favorite}, _from, state) do
    {:ok, character} = Managers.Character.lookup(state.character_id)

    state =
      with {:ok, achievement} <- fetch(state, achievement_id),
           {:ok, updated} <- Context.Achievements.update(achievement, %{favorite: favorite}) do
        maybe_push(character, Packets.Achievement.favorite(updated))
        put_achievement(state, updated)
      else
        _ -> state
      end

    {:reply, :ok, state}
  end

  @impl true
  def handle_cast(
        {:update, type, count, target_string, target_long, code_string, code_long},
        state
      ) do
    {:ok, character} = Managers.Character.lookup(state.character_id)

    event = %{
      type: type,
      count: count,
      target_string: target_string,
      target_long: target_long,
      code_string: code_string,
      code_long: code_long
    }

    state =
      Storage.Achievements.for_condition(type)
      |> Enum.reduce(state, &progress(&1, event, character, &2))

    {:noreply, state}
  end

  @impl true
  def handle_info(:flush, state) do
    Process.send_after(self(), :flush, @flush_interval)
    {:noreply, flush_dirty(state)}
  end

  @impl true
  def terminate(_reason, state) do
    flush_dirty(state)
  end

  # ---- progress ----

  defp progress(metadata, event, character, state) do
    if matches?(metadata, Map.get(state.achievements, metadata.id), event) do
      advance(metadata, event, character, state)
    else
      state
    end
  end

  defp matches?(metadata, achievement, %{type: type} = event) do
    case active_condition(metadata, achievement) do
      %{type: ^type} = condition ->
        Conditions.metadata_matches?(
          condition,
          event.target_string,
          event.target_long,
          event.code_string,
          event.code_long
        )

      _ ->
        false
    end
  end

  defp advance(metadata, event, character, state) do
    case ensure_achievement(metadata, state) do
      {:ok, achievement, state} ->
        {achievement, ranked_up?, trophies} =
          rank_up(metadata, achievement, state.trophies, character, event.type, event.count)

        state = %{state | trophies: trophies} |> put_achievement(achievement)

        unless ranked_up?,
          do: maybe_push_update(character, achievement, metadata)

        state

      :error ->
        state
    end
  end

  defp active_condition(metadata, nil),
    do: get_in(metadata, [:grades, Integer.to_string(lowest_grade(metadata)), :condition])

  defp active_condition(metadata, achievement),
    do: get_in(metadata, [:grades, Integer.to_string(achievement.current_grade), :condition])

  # a matching event creates the row immediately; later progress only
  # touches memory until the next flush
  defp ensure_achievement(metadata, %{achievements: achievements} = state) do
    case Map.get(achievements, metadata.id) do
      %Schema.Achievement{} = achievement ->
        {:ok, achievement, state}

      nil ->
        grade = lowest_grade(metadata)

        attrs = %{
          owner_id: owner_id(state, metadata),
          achievement_id: metadata.id,
          current_grade: grade,
          reward_grade: grade,
          category: metadata.category,
          grades: %{}
        }

        case Context.Achievements.create(attrs) do
          {:ok, achievement} -> {:ok, achievement, state}
          error -> error
        end
    end
  end

  defp rank_up(metadata, achievement, trophies, character, condition_type, count) do
    counter = counter_for(achievement, condition_type, count)
    achievement = %{achievement | counter: counter}
    walk_grades(metadata, achievement, trophies, character, false)
  end

  # gear score trophies track a maximum, every other condition accumulates
  defp counter_for(achievement, :item_gear_score, count), do: max(achievement.counter, count)
  defp counter_for(achievement, _condition_type, count), do: achievement.counter + count

  defp walk_grades(metadata, achievement, trophies, character, ranked_up?) do
    grade = get_in(metadata, [:grades, Integer.to_string(achievement.current_grade)])

    cond do
      grade == nil or achievement.counter < grade.condition.value ->
        {achievement, ranked_up?, trophies}

      map_size(achievement.grades) >= map_size(metadata.grades) ->
        {achievement, ranked_up?, trophies}

      true ->
        now = System.system_time(:second)
        grades = Map.put(achievement.grades, Integer.to_string(achievement.current_grade), now)
        completed? = map_size(grades) >= map_size(metadata.grades)

        achievement = %{
          achievement
          | grades: grades,
            current_grade:
              if(completed?,
                do: achievement.current_grade,
                else: achievement.current_grade + 1
              )
        }

        trophies = bump_trophies(trophies, achievement.category)

        {:ok, achievement} = give_reward(achievement, metadata, character, false)
        maybe_push_update(character, achievement, metadata)

        notify_quest_conditions(character.id, achievement)

        walk_grades(metadata, achievement, trophies, character, true)
    end
  end

  # grade completions feed back into quest conditions tracking other
  # achievements' progress
  defp notify_quest_conditions(character_id, achievement) do
    Enum.each(
      [:revise_achieve_multi_grade, :revise_achieve_single_grade, :hero_achieve],
      &Managers.Quest.update_conditions(
        character_id,
        &1,
        1,
        "",
        achievement.current_grade,
        "",
        achievement.achievement_id
      )
    )
  end

  defp bump_trophies(trophies, category) when category in 1..3,
    do: List.update_at(trophies, category - 1, &(&1 + 1))

  defp bump_trophies(trophies, _category), do: trophies

  # ---- rewards ----

  # Rewards that need no player interaction (stat points, emotes) are given
  # as soon as the grade is awarded; item and title rewards wait for the
  # player to claim them. Grades without a reward advance the reward grade
  # so the trophy UI shows completion instead of a claim button.
  defp give_reward(achievement, _metadata, _character, _manual?)
       when achievement.reward_grade > achievement.current_grade,
       do: {:ok, achievement}

  defp give_reward(achievement, metadata, character, manual?) do
    grade = get_in(metadata, [:grades, Integer.to_string(achievement.reward_grade)])
    reward = grade && grade[:reward]
    more_grades? = map_size(metadata.grades) > achievement.current_grade

    cond do
      is_nil(reward) and more_grades? ->
        {:ok,
         %{
           achievement
           | reward_grade: min(achievement.reward_grade + 1, achievement.current_grade)
         }}

      is_nil(reward) ->
        {:ok, %{achievement | reward_grade: achievement.reward_grade + 1}}

      true ->
        deliver_reward(reward, achievement, character, manual?)
    end
  end

  defp deliver_reward(%{type: :item} = reward, achievement, character, true) do
    item = Context.Items.init(reward.code, %{amount: reward.value, rarity: reward.rank})

    case Managers.Inventory.add_item(character, item) do
      {:ok, {_status, inventory_item} = result} ->
        push(character, Packets.InventoryItem.add_item(result, character))
        push(character, Packets.InventoryItem.mark_item_new(inventory_item))
        Managers.Quest.notify_item_acquired(character, inventory_item)
        {:ok, %{achievement | reward_grade: achievement.reward_grade + 1}}

      _ ->
        {:error, :inventory_full}
    end
  end

  defp deliver_reward(%{type: :title} = reward, achievement, character, true) do
    case Context.Characters.learn_title(character, reward.code) do
      {:ok, title} ->
        push(character, Packets.UserEnv.set_titles([title.title_id]))
        {:ok, %{achievement | reward_grade: achievement.reward_grade + 1}}

      _ ->
        {:error, :title_failed}
    end
  end

  defp deliver_reward(%{type: :statpoint} = reward, achievement, character, _manual?) do
    case Managers.Character.call(character, {:add_stat_point, :trophy, reward.value}) do
      {:ok, _character} -> {:ok, %{achievement | reward_grade: achievement.reward_grade + 1}}
      :error -> {:error, :statpoint_failed}
    end
  end

  defp deliver_reward(%{type: :dynamicaction} = reward, achievement, character, _manual?) do
    case Context.Emotes.learn(character, reward.code) do
      {:ok, _emote} ->
        push(character, Packets.Emote.learn(reward.code))

      # already known; the grade still counts as claimed
      {:error, _changeset} ->
        :ok
    end

    {:ok, %{achievement | reward_grade: achievement.reward_grade + 1}}
  end

  # TODO skill point rewards (the reference grants skill points with a
  # rank-based breakdown); no skill point API exists yet, so the grade
  # stays pending and can be claimed once support lands
  defp deliver_reward(%{type: :skillpoint}, _achievement, _character, _manual?),
    do: {:error, :skillpoint_unsupported}

  # cosmetic unlock types only drive client-side visuals
  defp deliver_reward(_reward, achievement, _character, _manual?),
    do: {:ok, %{achievement | reward_grade: achievement.reward_grade + 1}}

  # ---- state helpers ----

  defp fetch(state, achievement_id) do
    case Map.get(state.achievements, achievement_id) do
      nil -> :error
      achievement -> {:ok, achievement}
    end
  end

  defp put_achievement(state, achievement) do
    %{
      state
      | achievements: Map.put(state.achievements, achievement.achievement_id, achievement),
        dirty: MapSet.put(state.dirty, achievement.achievement_id)
    }
  end

  defp owner_id(state, metadata),
    do: if(metadata.account_wide, do: state.account_id, else: state.character_id)

  defp lowest_grade(metadata) do
    metadata.grades |> Map.keys() |> Enum.map(&String.to_integer/1) |> Enum.min()
  end

  defp count_trophies(achievements) do
    Enum.reduce(achievements, [0, 0, 0], fn {_id, achievement}, counts ->
      index = achievement.category - 1

      if index in 0..2 do
        List.update_at(counts, index, &(&1 + map_size(achievement.grades)))
      else
        counts
      end
    end)
  end

  defp maybe_push_update(%{session_pid: nil}, _achievement, _metadata), do: :ok

  defp maybe_push_update(character, achievement, metadata) do
    push(character, Packets.Achievement.update(Map.put(achievement, :metadata, metadata)))
  end

  defp maybe_push(%{session_pid: nil}, _packet), do: :ok
  defp maybe_push(character, packet), do: push(character, packet)

  # ---- persistence ----

  # rows are inserted when they are created, so flushing only ever updates
  defp flush_dirty(state) do
    Enum.each(state.dirty, fn achievement_id ->
      with {:ok, achievement} <- fetch(state, achievement_id) do
        Context.Achievements.save(achievement)
      end
    end)

    %{state | dirty: MapSet.new()}
  end
end
