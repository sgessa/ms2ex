defmodule Ms2ex.Context.Mastery do
  @moduledoc """
  Life skills: crafting mastery recipes and claiming the reward boxes each
  mastery grade hands out. Harvesting nodes is orchestrated on the character
  manager (`Managers.Character.Mastery`).

  Mastery values, gathering counts and claimed rewards live on the character
  process; this module drives the gameplay flows around them.
  """

  alias Ms2ex.Context
  alias Ms2ex.Managers
  alias Ms2ex.Managers.Character.Mastery
  alias Ms2ex.Packets
  alias Ms2ex.Schema
  alias Ms2ex.Storage

  import Ms2ex.Net.SenderSession, only: [push: 2]

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

  defp typed_exp(character, exp_type),
    do: Storage.Tables.ExpTable.typed_exp(exp_type, character.level)

  defp update_conditions(character, type, counter, code_long) do
    Managers.Quest.update_conditions(character.id, type, counter, "", 0, "", code_long)
  end
end
