defmodule Ms2ex.Storage.Tables.MasteryRecipes do
  @moduledoc """
  `masteryreceipe.xml`: one entry per gathering node and craft recipe, keyed
  by recipe id (the id an interact object's `item.recipe_id` points at).
  """

  alias Ms2ex.Storage

  @table_name "masteryreceipe.xml"

  @type item_component :: %{item_id: integer(), rarity: integer(), amount: integer(), tag: atom()}

  @type entry :: %{
          id: integer(),
          type: atom(),
          no_reward_exp: boolean(),
          required_mastery: integer(),
          required_meso: integer(),
          required_quests: [integer()],
          reward_exp: integer(),
          reward_mastery: integer(),
          high_rate_limit_count: integer(),
          normal_rate_limit_count: integer(),
          required_items: [item_component()],
          habitat_map_ids: [integer()],
          reward_items: [item_component()]
        }

  @spec lookup(integer()) :: {:ok, entry()} | :error
  def lookup(recipe_id) when is_integer(recipe_id) do
    :table
    |> Storage.get(@table_name)
    |> get_in([:table, :entries, recipe_id])
    |> case do
      nil -> :error
      entry -> {:ok, entry}
    end
  end

  def lookup(_recipe_id), do: :error
end
