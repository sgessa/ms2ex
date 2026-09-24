defmodule Ms2ex.Managers.Mastery do
  use GenServer
  use Ms2ex.Managers.Managed, prefix: "masteries", key: :character_id

  alias Ms2ex.Context
  alias Ms2ex.Enums
  alias Ms2ex.Formulas
  alias Ms2ex.Managers
  alias Ms2ex.Packets
  alias Ms2ex.Schema
  alias Ms2ex.Storage

  import Ms2ex.Net.SenderSession, only: [push: 2]

  @flush_interval :timer.minutes(1)

  # The mastery manager owns the life-skill domain for a character: mastery
  # values, claimed grade rewards and the harvest counters that decay the
  # gathering success rate. Mastery state is persisted on the characters row
  # (flushed periodically and on disconnect, so a gathering spree does not
  # write one UPDATE per node); harvest counters live on the character-config
  # row and are persisted per bump. The harvest flow (`gather/2`,
  # `bulk_gather/3`) is orchestrated here and runs in the caller's process
  # (the packet handler); state mutations route through this manager and the
  # contexts.

  def start(%Schema.Character{} = character) do
    case GenServer.start(__MODULE__, character, name: process_name(character.id)) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      error -> error
    end
  end

  def stop(%Schema.Character{id: id}), do: stop(id)

  def stop(id) when is_integer(id) do
    case Process.whereis(process_name(id)) do
      nil -> :ok
      pid -> GenServer.stop(pid)
    end
  end

  # ---- client API ----

  @doc "Mastery value of a type."
  @spec value(integer(), atom()) :: non_neg_integer() | :error
  def value(id, type), do: call(id, {:value, type})

  @doc "Mastery grade (level) a type has reached."
  @spec grade(integer(), atom()) :: non_neg_integer() | :error
  def grade(id, type), do: call(id, {:grade, type})

  @doc "Claimed mastery grade reward boxes, keyed by reward box id."
  @spec rewards_claimed(integer()) :: map() | :error
  def rewards_claimed(character_id), do: call(character_id, :rewards_claimed)

  @doc """
  Adds mastery. The value never decreases and is capped at the type's
  maximum; the client is told the new value and grade changes feed the
  matching trophy/quest conditions.
  """
  @spec add(integer(), atom(), integer(), keyword()) :: :ok | :error
  def add(id, type, amount, opts \\ []), do: call(id, {:add_mastery, type, amount, opts})

  @doc "Returns the character's harvest counters, keyed by recipe id."
  @spec gathering_counts(integer()) :: map() | :error
  def gathering_counts(character_id), do: call(character_id, :gathering_counts)

  @doc "Bumps the harvest counter of a gathering recipe and persists it."
  @spec bump_gathering_count(integer(), integer()) :: :ok | :error
  def bump_gathering_count(character_id, recipe_id),
    do: call(character_id, {:bump_gathering_count, recipe_id})

  @doc """
  Crafts a mastery recipe: consumes its ingredients and meso cost, awards
  the mastery and hands out the crafted items. Runs in the caller's process.
  """
  @spec craft(Schema.Character.t(), integer()) ::
          {:ok, Schema.Character.t()} | {:error, atom()}
  def craft(%Schema.Character{} = character, recipe_id) do
    with {:ok, recipe} <- Storage.Tables.MasteryRecipes.lookup(recipe_id),
         :ok <- check_quests(character, recipe),
         :ok <- check_mastery(character, recipe),
         :ok <- check_meso(character, recipe),
         :ok <- consume_ingredients(character, recipe) do
      {:ok, run_craft(character, recipe)}
    else
      :error -> {:error, :s_mastery_error_unknown}
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Claims the reward box of a mastery grade. The client addresses the box by
  `mastery_type * 1000 + grade`. Runs in the caller's process.
  """
  @spec claim_reward_box(Schema.Character.t(), integer()) ::
          {:ok, Schema.Character.t(), map()} | {:error, atom()}
  def claim_reward_box(%Schema.Character{} = character, reward_box_id) do
    type = Enums.MasteryType.get_key(div(reward_box_id, 1000))
    grade = rem(reward_box_id, 100)

    if call(character.id, {:claimed?, reward_box_id}) == true do
      {:error, :s_mastery_error_unknown}
    else
      case Storage.Tables.MasteryRewards.lookup(type, grade) do
        {:ok, entry} -> grant_reward(character, reward_box_id, type, entry)
        :error -> {:error, :s_mastery_error_unknown}
      end
    end
  end

  @doc "Drops the cached harvest counters after the daily reset cleared them."
  @spec reset_gathering_counts(integer()) :: :ok
  def reset_gathering_counts(character_id), do: cast(character_id, :reset_gathering_counts)

  # ---- harvesting (runs in the caller's process) ----

  @harvest_types [:farming, :mining, :gathering, :breeding]

  @doc """
  Harvests a gathering node. Returns the updated character and whether the
  harvest succeeded; failures still consume the attempt.
  """
  @spec gather(Schema.Character.t(), map()) ::
          {:ok, Schema.Character.t()} | {:error, atom(), Schema.Character.t()}
  def gather(%Schema.Character{} = character, object) do
    with {:ok, recipe} <- Storage.Tables.MasteryRecipes.lookup(object.recipe_id),
         :ok <- check_mastery(character, recipe) do
      run_gather(character, recipe, object)
    else
      :error -> {:error, :s_mastery_error_unknown, character}
      {:error, error} -> {:error, error, character}
    end
  end

  @doc """
  Harvests a recipe `amount` times without an interact object (the Smart Push
  bulk gather). Stops once the node's success rate has decayed to zero and
  returns how many harvests landed.
  """
  @spec bulk_gather(Schema.Character.t(), integer(), non_neg_integer()) ::
          {:ok, Schema.Character.t(), non_neg_integer()} | :error
  def bulk_gather(%Schema.Character{} = character, recipe_id, amount) do
    case Storage.Tables.MasteryRecipes.lookup(recipe_id) do
      {:ok, recipe} ->
        {character, count} =
          Enum.reduce_while(1..max(amount, 0)//1, {character, 0}, &bulk_step(&2, recipe, &1))

        {:ok, character, count}

      :error ->
        :error
    end
  end

  # ---- server callbacks ----

  @impl true
  def init(character) do
    Process.send_after(self(), :flush, @flush_interval)

    config = Context.CharacterConfigs.get(character.id)

    {:ok,
     %{
       character_id: character.id,
       # the loaded characters row, kept for the periodic persistence
       row: character,
       # the character-config row, kept so field updates can insert-or-update
       config: config,
       masteries: Map.get(character, :masteries) || %{},
       claimed: config.mastery_rewards_claimed,
       gathering_counts: config.gathering_counts,
       dirty?: false
     }}
  end

  @impl true
  def handle_call({:value, type}, _from, state),
    do: {:reply, Map.get(state.masteries, type, 0), state}

  @impl true
  def handle_call({:grade, type}, _from, state),
    do: {:reply, Storage.Tables.MasteryRewards.grade(type, Map.get(state.masteries, type, 0)), state}

  @impl true
  def handle_call(:rewards_claimed, _from, state), do: {:reply, state.claimed, state}

  @impl true
  def handle_call({:claimed?, reward_box_id}, _from, state),
    do: {:reply, Map.get(state.claimed, reward_box_id, false) == true, state}

  @impl true
  def handle_call({:claim_reward, reward_box_id}, _from, state) do
    if Map.get(state.claimed, reward_box_id, false) == true do
      {:reply, :error, state}
    else
      state = %{state | claimed: Map.put(state.claimed, reward_box_id, true), dirty?: true}
      {:reply, :ok, state}
    end
  end

  @impl true
  def handle_call({:add_mastery, type, amount, opts}, _from, state) do
    start_value = Map.get(state.masteries, type, 0)
    start_grade = Storage.Tables.MasteryRewards.grade(type, start_value)

    new_value =
      (start_value + amount)
      |> max(start_value)
      |> min(Enums.MasteryType.maximum(type))

    if new_value == start_value do
      {:reply, :ok, state}
    else
      state = %{state | masteries: Map.put(state.masteries, type, new_value), dirty?: true}

      push(state.row, Packets.Mastery.update_mastery(type, new_value))

      new_grade = Storage.Tables.MasteryRewards.grade(type, new_value)
      delta_grade = new_grade - start_grade + if(start_value == 0, do: 1, else: 0)

      notify_grade_change(state, type, new_grade, delta_grade)
      notify_exp_increase(state, type, new_value - start_value, opts)

      {:reply, :ok, state}
    end
  end

  @impl true
  def handle_call(:gathering_counts, _from, state),
    do: {:reply, state.gathering_counts, state}

  @impl true
  def handle_call({:bump_gathering_count, recipe_id}, _from, state) do
    counts = Map.update(state.gathering_counts, recipe_id, 1, &(&1 + 1))

    case Context.CharacterConfigs.update(state.config, %{gathering_counts: counts}) do
      {:ok, config} -> {:reply, :ok, %{state | config: config, gathering_counts: counts}}
      _ -> {:reply, :error, state}
    end
  end

  @impl true
  def handle_cast(:reset_gathering_counts, state) do
    push(state.row, Packets.UserEnv.gathering_counts(%{}))
    {:noreply, %{state | gathering_counts: %{}}}
  end

  @impl true
  def handle_info(:flush, state) do
    Process.send_after(self(), :flush, @flush_interval)
    {:noreply, flush(state)}
  end

  @impl true
  def terminate(_reason, state), do: flush(state)

  # a grade loss only refreshes the client's grade trophy; a gain feeds the
  # per-skill trophies
  defp notify_grade_change(_state, _type, _grade, 0), do: :ok

  defp notify_grade_change(state, type, _grade, delta) when delta < 0 do
    update_conditions(state, :set_mastery_grade, 1, Enums.MasteryType.get_value(type))
  end

  defp notify_grade_change(state, :fishing, grade, _delta),
    do: update_conditions(state, :fisher_grade, 1, grade)

  defp notify_grade_change(state, :music, _grade, delta),
    do: update_conditions(state, :music_play_grade, delta, 0)

  defp notify_grade_change(state, type, _grade, _delta),
    do: update_conditions(state, :mastery_grade, 1, Enums.MasteryType.get_value(type))

  defp notify_exp_increase(state, :music, delta_exp, opts) do
    update_conditions(
      state,
      :music_play_instrument_mastery,
      delta_exp,
      Keyword.get(opts, :instrument_category, 0)
    )
  end

  defp notify_exp_increase(_state, _type, _delta_exp, _opts), do: :ok

  defp update_conditions(state, type, counter, code_long) do
    Managers.Quest.update_conditions(state.character_id, type, counter, "", 0, "", code_long)
  end

  # mastery values are persisted on the characters row on the periodic
  # flush and on disconnect; claimed grade rewards live on the config row
  defp flush(%{dirty?: false} = state), do: state

  defp flush(state) do
    with {:ok, row} <-
           Context.Characters.persist(state.row, %{masteries: state.masteries}),
         {:ok, config} <-
           Context.CharacterConfigs.update(state.config, %{
             mastery_rewards_claimed: state.claimed
           }) do
      %{state | row: row, config: config, dirty?: false}
    else
      _ -> state
    end
  end

  # ---- harvest flow internals ----

  defp bulk_step({character, count}, recipe, _step) do
    if success_rate(character, recipe) <= 0 do
      {:halt, {character, count}}
    else
      before_gather(character, recipe)
      character = harvest(character, recipe, %{position: character.position})
      {:cont, {character, count + 1}}
    end
  end

  defp run_gather(character, recipe, object) do
    rate = success_rate(character, recipe)

    before_gather(character, recipe)

    if :rand.uniform() * 100 > rate do
      {:error, :failed, character}
    else
      {:ok, harvest(character, recipe, object)}
    end
  end

  defp harvest(character, recipe, object) do
    character
    |> drop_rewards(recipe, object)
    |> after_gather(recipe)
    |> count_gather(recipe)
    |> award_gather_exp(recipe)
    |> award_gather_mastery(recipe)
  end

  defp success_rate(character, recipe) do
    current_count = Map.get(gathering_counts(character.id), recipe.id, 0)

    Formulas.Gathering.success_rate(
      current_count,
      recipe.high_rate_limit_count,
      recipe.normal_rate_limit_count
    )
  end

  defp drop_rewards(character, recipe, object) do
    for reward <- recipe.reward_items do
      case Context.Items.drop_item(reward.item_id, reward.rarity, reward.amount) do
        %Schema.Item{} = item ->
          Managers.Field.drop_item(character, item, object.position)

        _ ->
          :ok
      end
    end

    character
  end

  defp count_gather(character, recipe) do
    bump_gathering_count(character.id, recipe.id)
    character
  end

  defp award_gather_exp(character, %{no_reward_exp: true}), do: character

  defp award_gather_exp(character, _recipe) do
    Managers.Character.cast(character, {:earn_exp, typed_exp(character, :gathering)})
    character
  end

  # a recipe that sits too far below the player's grade stops awarding
  # mastery entirely
  defp award_gather_mastery(character, %{type: type} = recipe) when type in @harvest_types do
    if value(character.id, type) - recipe.reward_mastery >=
         Storage.Tables.MasteryDifferentialFactors.positive_factor_count() do
      character
    else
      add(character.id, type, recipe.reward_mastery)
      character
    end
  end

  defp award_gather_mastery(character, recipe) do
    add(character.id, recipe.type, recipe.reward_mastery)
    character
  end

  defp before_gather(character, %{type: type} = recipe) when type in [:farming, :breeding] do
    update_conditions(%{character_id: character.id}, :mastery_harvest_try, 1, recipe.id)
    update_conditions(%{character_id: character.id}, :mastery_farming_try, 1, recipe.id)
  end

  defp before_gather(character, %{type: type} = recipe) when type in [:gathering, :mining] do
    update_conditions(%{character_id: character.id}, :mastery_gathering_try, 1, recipe.id)
  end

  defp before_gather(_character, _recipe), do: :ok

  defp after_gather(character, %{type: type} = recipe) when type in [:farming, :breeding] do
    if type == :farming do
      update_conditions(%{character_id: character.id}, :mastery_farming, 1, recipe.id)
    end

    update_conditions(%{character_id: character.id}, :mastery_harvest, 1, recipe.id)
    character
  end

  defp after_gather(character, %{type: type} = recipe) when type in [:gathering, :mining] do
    update_conditions(%{character_id: character.id}, :mastery_gathering, 1, recipe.id)
    character
  end

  defp after_gather(character, _recipe), do: character

  defp typed_exp(character, exp_type),
    do: Storage.Tables.ExpTable.typed_exp(exp_type, character.level)

  defp check_mastery(character, recipe) do
    if value(character.id, recipe.type) >= recipe.required_mastery do
      :ok
    else
      {:error, :s_mastery_error_lack_mastery}
    end
  end

  # ---- crafting internals ----

  defp run_craft(character, recipe) do
    Context.Wallets.update(character, :mesos, -recipe.required_meso)

    character =
      if recipe.no_reward_exp do
        character
      else
        add(character.id, recipe.type, recipe.reward_mastery)
        character
      end

    for reward <- recipe.reward_items do
      case Context.Items.drop_item(reward.item_id, reward.rarity, reward.amount) do
        %Schema.Item{} = item -> grant_item(character, item)
        _ -> :ok
      end
    end

    unless recipe.no_reward_exp do
      Managers.Character.cast(character, {:earn_exp, typed_exp(character, :manufacturing)})
    end

    update_conditions(%{character_id: character.id}, :mastery_manufacturing, 1, recipe.id)

    character
  end

  defp grant_reward(character, reward_box_id, type, entry) do
    if value(character.id, type) < entry.value do
      {:error, :s_mastery_error_invalid_level}
    else
      with %Schema.Item{} = item <-
             Context.Items.drop_item(entry.item_id, entry.item_rarity, entry.item_amount),
           :ok <- call(character.id, {:claim_reward, reward_box_id}),
           :ok <- grant_item(character, item) do
        {:ok, character, %{item_id: entry.item_id, rarity: entry.item_rarity}}
      else
        {:error, error} when is_atom(error) -> {:error, error}
        _ -> {:error, :s_mastery_error_unknown}
      end
    end
  end

  defp grant_item(character, item) do
    case Managers.Inventory.add_item_or_mail(character, item) do
      {:ok, result} ->
        {_status, inventory_item} = result
        push(character, Packets.InventoryItem.add_item(result, character))
        push(character, Packets.InventoryItem.mark_item_new(inventory_item))
        Managers.Quest.notify_item_acquired(character, inventory_item)
        :ok

      {:mailed, _mail} ->
        :ok

      _ ->
        :ok
    end
  end

  # the reference sends the error but keeps crafting; refusing the craft is
  # the intended behaviour
  defp check_quests(character, recipe) do
    missing? =
      Enum.any?(recipe.required_quests, fn quest_id ->
        Managers.Quest.get_quest(character.id, quest_id) == nil
      end)

    if missing?, do: {:error, :s_mastery_error_lack_quest}, else: :ok
  end

  defp check_meso(_character, %{required_meso: meso}) when meso <= 0, do: :ok

  defp check_meso(character, %{required_meso: meso}) do
    case Context.Wallets.find(character) do
      %Schema.Wallet{mesos: mesos} when mesos >= meso -> :ok
      _ -> {:error, :s_mastery_error_lack_meso}
    end
  end

  defp consume_ingredients(_character, %{required_items: []}), do: :ok

  defp consume_ingredients(character, %{required_items: required}) do
    consumables = Enum.map(required, &%{item_id: &1.item_id, amount: &1.amount})
    carried = Managers.Inventory.list_items(character)

    if Enum.all?(consumables, &owns?(carried, &1)) do
      {:ok, results} = Managers.Inventory.consume_item_amounts(character, consumables)
      Enum.each(results, &push(character, Packets.InventoryItem.consume(&1)))
      :ok
    else
      {:error, :s_mastery_error_lack_item}
    end
  end

  defp owns?(carried, %{item_id: item_id, amount: amount}) do
    carried
    |> Enum.filter(&(&1.item_id == item_id))
    |> Enum.map(& &1.amount)
    |> Enum.sum()
    |> Kernel.>=(amount)
  end
end
