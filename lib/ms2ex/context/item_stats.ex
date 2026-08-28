defmodule Ms2ex.Context.ItemStats do
  @moduledoc """
  Aggregates the stat bonuses granted by equipped items and applies them to a
  character's stats.

  Each item's calculated stats are summed over every equipped item and added
  to the character's base stat values.
  """

  alias Ms2ex.Context
  alias Ms2ex.Enums
  alias Ms2ex.Formulas.BaseStats
  alias Ms2ex.Formulas.GearScore
  alias Ms2ex.Repo
  alias Ms2ex.Schema

  @item_stat_groups [:constants, :statics, :randoms, :enchants, :limit_break_enchants]

  @doc """
  Stat bonuses granted by a single item.
  """
  def bonuses(%Schema.Item{} = item) do
    item_stat_values(item, :basic)
  end

  @doc """
  Rebuilds a character's stats from the persisted base plus the bonuses of
  every equipped item. The base is reloaded so repeated applications never
  stack.
  """
  def apply(%Schema.Character{} = character) do
    character = Repo.preload(character, :stats, force: true)
    equips = equipped_gear(character)

    {bonuses, rates, special_values, special_rates} =
      Enum.reduce(equips, {%{}, %{}, %{}, %{}}, fn item,
                                                   {bonuses, rates, special_values, special_rates} ->
        {
          merge_values(bonuses, item_stat_values(item, :basic)),
          merge_values(rates, item_stat_rates(item, :basic)),
          merge_values(special_values, item_stat_values(item, :special)),
          merge_values(special_rates, item_stat_rates(item, :special))
        }
      end)

    character = reset_base_stats(character)
    character = apply_stats(character, bonuses, rates)
    character = put_stat_metadata(character, rates, special_values, special_rates)
    %{character | gear_score: calculate_gear_score(equips)}
  end

  @doc """
  Adds a map of stat bonuses to a character's current and maximum stats.
  """
  def apply_stats(%Schema.Character{} = character, bonuses) do
    apply_stats(character, bonuses, %{})
  end

  defp apply_stats(%Schema.Character{} = character, bonuses, rates) do
    stats =
      Enum.reduce(bonuses, character.stats, fn {stat, amount}, stats ->
        stats
        |> Map.update(:"#{stat}_max", amount, &(&1 + amount))
        |> Map.update(:"#{stat}_cur", amount, &(&1 + amount))
      end)

    stats =
      Enum.reduce(rates, stats, fn {stat, rate}, stats ->
        max = Map.get(stats, :"#{stat}_max", 0)
        total = max + trunc(max * rate)

        stats
        |> Map.put(:"#{stat}_max", total)
        |> Map.put(:"#{stat}_cur", total)
      end)

    %{character | stats: stats}
  end

  defp reset_base_stats(%Schema.Character{stats: stats} = character) do
    stats =
      Enum.reduce(BaseStats.all(character.job, character.level), stats, fn {stat, value}, stats ->
        stats
        |> Map.put(:"#{stat}_min", value)
        |> Map.put(:"#{stat}_cur", value)
        |> Map.put(:"#{stat}_max", value)
      end)

    %{character | stats: stats}
  end

  defp item_stat_values(item, class) do
    item
    |> item_stats()
    |> Enum.reduce(%{}, fn stat, acc ->
      if stat.class == class and (stat.type == :flat or stat.attribute == :piercing) do
        value = if stat.type == :rate, do: round(stat.value * 1000), else: trunc(stat.value)
        Map.update(acc, stat.attribute, value, &(&1 + value))
      else
        acc
      end
    end)
  end

  defp item_stat_rates(item, class) do
    item
    |> item_stats()
    |> Enum.reduce(%{}, fn stat, acc ->
      if stat.class == class and stat.type == :rate and stat.attribute != :piercing do
        Map.update(acc, stat.attribute, stat.value, &(&1 + stat.value))
      else
        acc
      end
    end)
  end

  defp put_stat_metadata(
         %Schema.Character{stats: stats} = character,
         basic_rates,
         special_values,
         special_rates
       ) do
    stats =
      stats
      |> Map.put(:basic_rates, basic_rates)
      |> Map.put(:special_values, special_values)
      |> Map.put(:special_rates, special_rates)

    %{character | stats: stats}
  end

  defp item_stats(item) do
    Enum.flat_map(@item_stat_groups, fn group ->
      item.stats
      |> Map.get(group, %{})
      |> Map.values()
    end)
  end

  defp equipped_gear(character) do
    equips =
      case Map.get(character, :equips) do
        equips when is_list(equips) -> equips
        _ -> Context.Equips.list(character)
      end

    Enum.filter(equips, &(&1.inventory_tab == :gear))
  end

  defp calculate_gear_score(equips) do
    equips
    |> Enum.map(fn item ->
      %{
        gear_score: get_in(item.metadata, [:property, :gear_score]) || 0,
        rarity: item.rarity || 0,
        item_type: item_type(item),
        enchant_level: item.enchant_level || 0,
        limit_break_level: item.limit_break_level || 0
      }
    end)
    |> GearScore.calculate()
  end

  defp item_type(item) do
    item.item_id
    |> Context.ItemTypes.get_type_by_item_id()
    |> Enums.ItemType.get_value()
  end

  defp merge_values(left, right) do
    Map.merge(left, right, fn _stat, left_value, right_value -> left_value + right_value end)
  end
end
