defmodule Ms2ex.Managers.Character.Mastery do
  @moduledoc """
  Life skill (mastery) state owned by the character process: the mastery
  value per type and which grade reward boxes were claimed.

  Everything is read from and written to memory; the row is only persisted
  on the periodic flush and on disconnect, so a gathering spree does not
  write one UPDATE per node. Harvest counters live in the character-config
  manager (see `Ms2ex.Managers.CharacterConfig`).

  The harvest flow (`gather/2`, `bulk_gather/3`) is orchestrated here and
  runs in the caller's process (the packet handler); state mutations still
  route through the owning managers and contexts.
  """

  alias Ms2ex.Context
  alias Ms2ex.Enums
  alias Ms2ex.Formulas
  alias Ms2ex.Managers
  alias Ms2ex.Packets
  alias Ms2ex.Schema
  alias Ms2ex.Storage

  import Ms2ex.Net.SenderSession, only: [push: 2]

  @doc "Mastery values of a character, keyed by mastery type."
  def all(character) do
    case Map.get(character, :masteries) do
      masteries when is_map(masteries) -> masteries
      _ -> %{}
    end
  end

  @doc "Mastery value of a single type."
  def value(character, type), do: Map.get(all(character), type, 0)

  @doc "Mastery grade (level) a type has reached."
  def grade(character, type),
    do: Storage.Tables.MasteryRewards.grade(type, value(character, type))

  @doc "Claimed mastery grade reward boxes, keyed by reward box id."
  def rewards_claimed(character) do
    case Map.get(character, :mastery_rewards_claimed) do
      claimed when is_map(claimed) -> claimed
      _ -> %{}
    end
  end

  def claimed?(character, reward_box_id),
    do: Map.get(rewards_claimed(character), reward_box_id, false) == true

  def claim(character, reward_box_id) do
    character
    |> Map.put(:mastery_rewards_claimed, Map.put(rewards_claimed(character), reward_box_id, true))
    |> mark_dirty()
  end

  @doc """
  Adds mastery. The value never decreases and is capped at the type's
  maximum; the client is told the new value and grade changes feed the
  matching trophy/quest conditions.
  """
  def add(character, type, amount, opts \\ [])

  def add(character, type, amount, opts) when is_integer(amount) do
    start_value = value(character, type)
    start_grade = Storage.Tables.MasteryRewards.grade(type, start_value)

    new_value =
      (start_value + amount)
      |> max(start_value)
      |> min(Enums.MasteryType.maximum(type))

    if new_value == start_value do
      character
    else
      character =
        character
        |> Map.put(:masteries, Map.put(all(character), type, new_value))
        |> mark_dirty()

      push(character, Packets.Mastery.update_mastery(type, new_value))

      new_grade = Storage.Tables.MasteryRewards.grade(type, new_value)
      delta_grade = new_grade - start_grade + if(start_value == 0, do: 1, else: 0)

      notify_grade_change(character, type, new_grade, delta_grade)
      notify_exp_increase(character, type, new_value - start_value, opts)

      character
    end
  end

  def add(character, _type, _amount, _opts), do: character

  @doc "Persists the mastery state when it changed since the last flush."
  def flush(%{mastery_dirty?: true} = character) do
    attrs = %{
      masteries: all(character),
      mastery_rewards_claimed: rewards_claimed(character),
      fish_album: Managers.Character.Fishing.album(character)
    }

    case Context.Characters.persist(character, attrs) do
      {:ok, updated} -> Map.put(updated, :mastery_dirty?, false)
      _ -> character
    end
  end

  def flush(character), do: character

  defp mark_dirty(character), do: Map.put(character, :mastery_dirty?, true)

  # a grade loss only refreshes the client's grade trophy; a gain feeds the
  # per-skill trophies
  defp notify_grade_change(_character, _type, _grade, 0), do: :ok

  defp notify_grade_change(character, type, _grade, delta) when delta < 0 do
    update_conditions(character, :set_mastery_grade, 1, Enums.MasteryType.get_value(type))
  end

  defp notify_grade_change(character, :fishing, grade, _delta),
    do: update_conditions(character, :fisher_grade, 1, grade)

  defp notify_grade_change(character, :music, _grade, delta),
    do: update_conditions(character, :music_play_grade, delta, 0)

  defp notify_grade_change(character, type, _grade, _delta),
    do: update_conditions(character, :mastery_grade, 1, Enums.MasteryType.get_value(type))

  defp notify_exp_increase(character, :music, delta_exp, opts) do
    update_conditions(
      character,
      :music_play_instrument_mastery,
      delta_exp,
      Keyword.get(opts, :instrument_category, 0)
    )
  end

  defp notify_exp_increase(_character, _type, _delta_exp, _opts), do: :ok

  defp update_conditions(character, type, counter, code_long) do
    Managers.Quest.update_conditions(character.id, type, counter, "", 0, "", code_long)
  end

  # ---- harvesting ----

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
    current_count = Map.get(Managers.CharacterConfig.gathering_counts(character.id), recipe.id, 0)

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
    Managers.CharacterConfig.bump_gathering_count(character.id, recipe.id)
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
    if value(character, type) - recipe.reward_mastery >=
         Storage.Tables.MasteryDifferentialFactors.positive_factor_count() do
      character
    else
      add_through_character(character, type, recipe.reward_mastery)
    end
  end

  defp award_gather_mastery(character, recipe),
    do: add_through_character(character, recipe.type, recipe.reward_mastery)

  defp add_through_character(character, type, amount) do
    case Managers.Character.call(character.id, {:add_mastery, type, amount, []}) do
      {:ok, character} -> character
      _ -> character
    end
  end

  defp before_gather(character, %{type: type} = recipe) when type in [:farming, :breeding] do
    update_conditions(character, :mastery_harvest_try, 1, recipe.id)
    update_conditions(character, :mastery_farming_try, 1, recipe.id)
  end

  defp before_gather(character, %{type: type} = recipe) when type in [:gathering, :mining] do
    update_conditions(character, :mastery_gathering_try, 1, recipe.id)
  end

  defp before_gather(_character, _recipe), do: :ok

  defp after_gather(character, %{type: type} = recipe) when type in [:farming, :breeding] do
    if type == :farming do
      update_conditions(character, :mastery_farming, 1, recipe.id)
    end

    update_conditions(character, :mastery_harvest, 1, recipe.id)
    character
  end

  defp after_gather(character, %{type: type} = recipe) when type in [:gathering, :mining] do
    update_conditions(character, :mastery_gathering, 1, recipe.id)
    character
  end

  defp after_gather(character, _recipe), do: character

  defp typed_exp(character, exp_type),
    do: Storage.Tables.ExpTable.typed_exp(exp_type, character.level)

  defp check_mastery(character, recipe) do
    if value(character, recipe.type) >= recipe.required_mastery do
      :ok
    else
      {:error, :s_mastery_error_lack_mastery}
    end
  end
end
