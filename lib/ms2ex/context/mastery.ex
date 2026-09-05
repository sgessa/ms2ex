defmodule Ms2ex.Context.Mastery do
  @moduledoc """
  Life skills: harvesting gathering nodes and crafting mastery recipes, plus
  claiming the reward boxes each mastery grade hands out.

  Mastery values, gathering counts and claimed rewards live on the character
  process (`Managers.Character.Mastery`); this module drives the gameplay
  flows around them.
  """

  alias Ms2ex.Context
  alias Ms2ex.Formulas
  alias Ms2ex.Managers
  alias Ms2ex.Managers.Character.Mastery
  alias Ms2ex.Packets
  alias Ms2ex.Schema
  alias Ms2ex.Storage

  import Ms2ex.Net.SenderSession, only: [push: 2]

  @harvest_types [:farming, :mining, :gathering, :breeding]

  @doc "Mastery value of a type."
  def value(character, type), do: Mastery.value(character, type)

  @doc "Mastery grade (level) of a type."
  def grade(character, type), do: Mastery.grade(character, type)

  @doc """
  Adds mastery through the character process so the authoritative value is
  the one in memory.
  """
  def add(%Schema.Character{} = character, type, amount, opts \\ []) do
    case Managers.Character.call(character.id, {:add_mastery, type, amount, opts}) do
      {:ok, character} -> character
      _ -> character
    end
  end

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

  @doc """
  Crafts a mastery recipe: consumes its ingredients and meso cost, awards the
  mastery and hands out the crafted items.
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
  `mastery_type * 1000 + grade`.
  """
  @spec claim_reward(Schema.Character.t(), integer()) ::
          {:ok, Schema.Character.t(), map()} | {:error, atom()}
  def claim_reward(%Schema.Character{} = character, reward_box_id) do
    type = Ms2ex.Enums.MasteryType.get_key(div(reward_box_id, 1000))
    grade = rem(reward_box_id, 100)

    if Mastery.claimed?(character, reward_box_id) do
      {:error, :s_mastery_error_unknown}
    else
      case Storage.Tables.MasteryRewards.lookup(type, grade) do
        {:ok, entry} -> grant_reward(character, reward_box_id, type, entry)
        :error -> {:error, :s_mastery_error_unknown}
      end
    end
  end

  defp grant_reward(character, reward_box_id, type, entry) do
    if Mastery.value(character, type) < entry.value do
      {:error, :s_mastery_error_invalid_level}
    else
      with %Schema.Item{} = item <-
             Context.Items.drop_item(entry.item_id, entry.item_rarity, entry.item_amount),
           {:ok, character} <-
             Managers.Character.call(character.id, {:claim_mastery_reward, reward_box_id}),
           :ok <- grant_item(character, item) do
        {:ok, character, %{item_id: entry.item_id, rarity: entry.item_rarity}}
      else
        {:error, error} when is_atom(error) -> {:error, error}
        _ -> {:error, :s_mastery_error_unknown}
      end
    end
  end

  # ---- gathering ----

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
    current_count = Map.get(Mastery.gathering_counts(character), recipe.id, 0)

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
          Context.Field.drop_item(character, item, object.position)

        _ ->
          :ok
      end
    end

    character
  end

  defp count_gather(character, recipe) do
    case Managers.Character.call(character.id, {:count_gather, recipe.id}) do
      {:ok, character} -> character
      _ -> character
    end
  end

  defp award_gather_exp(character, %{no_reward_exp: true}), do: character

  defp award_gather_exp(character, _recipe) do
    Managers.Character.cast(character, {:earn_exp, typed_exp(character, :gathering)})
    character
  end

  # a recipe that sits too far below the player's grade stops awarding
  # mastery entirely
  defp award_gather_mastery(character, %{type: type} = recipe) when type in @harvest_types do
    if Mastery.grade(character, type) - recipe.reward_mastery >=
         Storage.Tables.MasteryDifferentialFactors.positive_factor_count() do
      character
    else
      add(character, type, recipe.reward_mastery)
    end
  end

  defp award_gather_mastery(character, recipe),
    do: add(character, recipe.type, recipe.reward_mastery)

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

  # ---- crafting ----

  defp run_craft(character, recipe) do
    Context.Wallets.update(character, :mesos, -recipe.required_meso)

    character =
      if recipe.no_reward_exp do
        character
      else
        add(character, recipe.type, recipe.reward_mastery)
      end

    for reward <- recipe.reward_items do
      case Context.Items.drop_item(reward.item_id, reward.rarity, reward.amount) do
        %Schema.Item{} = item -> grant_item(character, item)
        _ -> :ok
      end
    end

    Managers.Character.cast(character, {:earn_exp, typed_exp(character, :manufacturing)})
    update_conditions(character, :mastery_manufacturing, 1, recipe.id)

    character
  end

  # the reference sends the error but keeps crafting; refusing the craft is
  # the intended behaviour
  defp check_mastery(character, recipe) do
    if Mastery.value(character, recipe.type) >= recipe.required_mastery do
      :ok
    else
      {:error, :s_mastery_error_lack_mastery}
    end
  end

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
      %{mesos: mesos} when mesos >= meso -> :ok
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

  # ---- shared ----

  defp grant_item(character, item) do
    case Managers.Inventory.add_item(character, item) do
      {:ok, result} ->
        push(character, Packets.InventoryItem.add_item(result, character))
        Managers.Quest.notify_item_acquired(character, elem(result, tuple_size(result) - 1))
        :ok

      _ ->
        {:error, :s_mastery_error_unknown}
    end
  end

  defp typed_exp(character, exp_type),
    do: Storage.Tables.ExpTable.typed_exp(exp_type, character.level)

  defp update_conditions(character, type, counter, code_long) do
    Managers.Quest.update_conditions(character.id, type, counter, "", 0, "", code_long)
  end
end
