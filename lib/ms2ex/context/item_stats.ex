defmodule Ms2ex.Context.ItemStats do
  @moduledoc """
  Aggregates the stat bonuses granted by equipped items and learned passive
  skills, then applies them to a character's stats.

  Calculated item and passive effects are summed and added to the character's
  base stat values.
  """

  alias Ms2ex.Context
  alias Ms2ex.Enums
  alias Ms2ex.Formulas.BaseStats
  alias Ms2ex.Formulas.GearScore
  alias Ms2ex.Schema
  alias Ms2ex.Storage

  @item_stat_groups [:constants, :statics, :randoms, :enchants, :limit_break_enchants]
  @empty_stat_groups %{values: %{}, rates: %{}, special_values: %{}, special_rates: %{}}

  @doc """
  Rebuilds a character's stats and returns the derived packet data.
  """
  def apply(%Schema.Character{} = character) do
    equips = equipped_gear(character)

    stat_groups =
      Enum.reduce(equips, @empty_stat_groups, fn item, stat_groups ->
        stat_groups
        |> merge_stat_groups(item_stat_groups(item))
        |> merge_stat_groups(item_effect_stats(item))
      end)

    stat_groups = merge_stat_groups(stat_groups, passive_effect_stats(character))

    character = reset_base_stats(character)
    character = apply_stats(character, stat_groups.values, stat_groups.rates)

    equipment_stats = %{
      basic_rates: stat_groups.rates,
      special_values: stat_groups.special_values,
      special_rates: stat_groups.special_rates
    }

    {%{character | gear_score: calculate_gear_score(equips)}, equipment_stats}
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
      case stat do
        %{class: ^class, type: :flat} -> add_stat_value(acc, stat)
        %{class: ^class, attribute: :piercing} -> add_stat_value(acc, stat)
        _ -> acc
      end
    end)
  end

  defp add_stat_value(acc, %{attribute: attribute, type: type, value: value}) do
    value = if type == :rate, do: round(value * 1000), else: trunc(value)
    Map.update(acc, attribute, value, &(&1 + value))
  end

  defp item_stat_rates(item, class) do
    item
    |> item_stats()
    |> Enum.reduce(
      %{},
      fn
        stat, acc
        when stat.class == class and stat.type == :rate and stat.attribute != :piercing ->
          Map.update(acc, stat.attribute, stat.value, &(&1 + stat.value))

        _stat, acc ->
          acc
      end
    )
  end

  defp item_stats(item) do
    Enum.flat_map(@item_stat_groups, fn group ->
      item.stats
      |> Map.get(group, %{})
      |> Map.values()
    end)
  end

  defp item_stat_groups(item) do
    %{
      values: item_stat_values(item, :basic),
      rates: item_stat_rates(item, :basic),
      special_values: item_stat_values(item, :special),
      special_rates: item_stat_rates(item, :special)
    }
  end

  defp item_effect_stats(item) do
    effects = Map.get(item.metadata, :additional_effects, [])

    effect_stats(effects)
  end

  defp passive_effect_stats(%Schema.Character{} = character) do
    character
    |> Context.Skills.get_active_tab()
    |> case do
      %Schema.SkillTab{skills: skills} ->
        Enum.reduce(skills, @empty_stat_groups, &merge_passive_skill/2)

      _ ->
        @empty_stat_groups
    end
  end

  defp merge_passive_skill(skill, stats) do
    [skill | Map.get(skill, :sub_skills, []) || []]
    |> Enum.filter(&learned_passive?/1)
    |> Enum.reduce(stats, fn passive_skill, stats ->
      merge_stat_groups(stats, skill_effect_stats(passive_skill))
    end)
  end

  defp learned_passive?(%{skill_id: id, level: level}) when level > 0 do
    match?(%{property: %{type: 1}}, Storage.Skills.get_meta(id))
  end

  defp learned_passive?(_skill), do: false

  defp skill_effect_stats(%{skill_id: id, level: level}) do
    case Storage.Skills.get_meta(id) do
      %{levels: levels} ->
        effects = get_in(levels, [Integer.to_string(level), :skills]) || []

        effect_stats(Enum.flat_map(effects, &Map.get(&1, :skills, [])))

      _ ->
        @empty_stat_groups
    end
  end

  defp effect_stats(effects) do
    Enum.reduce(effects, @empty_stat_groups, fn %{id: id, level: level}, stats ->
      case Storage.Skills.get_effect(id, level) do
        %{status: status} ->
          merge_stat_groups(stats, %{
            values: Map.get(status, :values, %{}),
            rates: Map.get(status, :rates, %{}),
            special_values: Map.get(status, :special_values, %{}),
            special_rates: Map.get(status, :special_rates, %{})
          })

        _ ->
          stats
      end
    end)
  end

  defp merge_stat_groups(left, right) do
    Map.merge(left, right, fn _group, left_values, right_values ->
      merge_values(left_values, right_values)
    end)
  end

  defp equipped_gear(character) do
    # metadata is not cached on the character; it is read from the storage
    # cache while the stats are rebuilt
    character.equips
    |> Enum.filter(&(&1.inventory_tab == :gear))
    |> Enum.map(&Context.Items.load_metadata(&1))
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

  defp merge_values(left, right),
    do: Map.merge(left, right, fn _stat, left_value, right_value -> left_value + right_value end)
end
