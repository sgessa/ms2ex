defmodule Ms2ex.Context.ItemStats do
  @moduledoc """
  Aggregates the stat bonuses granted by equipped items and applies them to a
  character's stats.

  Each item's constant and static option stats are calculated in Elixir, then
  summed over every equipped item and added to the character's current and
  maximum stat values.
  """

  alias Ms2ex.Context
  alias Ms2ex.Repo
  alias Ms2ex.Schema
  alias Ms2ex.Storage

  @doc """
  Stat bonuses granted by a single item: its constant plus static value stats.
  """
  def bonuses(%Schema.Item{} = item) do
    option = item.metadata.option

    pick = Storage.Tables.ItemOptions.find_pick(option.pick_id, item.rarity)
    constant = Storage.Tables.ItemOptions.find_constant(option.constant_id, item.rarity)
    static = Storage.Tables.ItemOptions.find_static(option.static_id, item.rarity)

    Map.merge(
      value_stats(:constant, pick[:constant_value], constant[:values], item),
      value_stats(:static, pick[:static_value], static[:values], item),
      fn _stat, left, right -> left + right end
    )
  end

  @doc """
  Rebuilds a character's stats from the persisted base plus the bonuses of
  every equipped item. The base is reloaded so repeated applications never
  stack.
  """
  def apply(%Schema.Character{} = character) do
    character = Repo.preload(character, :stats)
    equips = Map.get(character, :equips) || Context.Equips.list(character)

    bonuses =
      Enum.reduce(equips, %{}, fn item, acc ->
        Map.merge(acc, bonuses(item), fn _stat, left, right -> left + right end)
      end)

    apply_stats(character, bonuses)
  end

  @doc """
  Adds a map of stat bonuses to a character's current and maximum stats.
  """
  def apply_stats(%Schema.Character{} = character, bonuses) do
    stats =
      Enum.reduce(bonuses, character.stats, fn {stat, amount}, stats ->
        stats
        |> Map.update(:"#{stat}_cur", amount, &(&1 + amount))
        |> Map.update(:"#{stat}_max", amount, &(&1 + amount))
      end)

    %{character | stats: stats}
  end

  defp value_stats(type, pick_list, values, item) do
    allowed = Context.ItemStatsCalculator.allowed_stats(type)

    Enum.reduce(pick_list || [], %{}, fn {stat, deviation}, acc ->
      if Map.has_key?(allowed, stat) do
        add_stat(acc, type, stat, deviation, values, item)
      else
        acc
      end
    end)
  end

  defp add_stat(acc, type, stat, deviation, values, item) do
    base = Map.get(values || %{}, stat, 0)

    case compute_value(type, stat, base, deviation, item) do
      {:ok, value} -> Map.update(acc, stat, value, &(&1 + value))
      :error -> acc
    end
  end

  defp compute_value(:constant, stat, base, deviation, item) do
    {:ok, trunc(Context.ItemStatsCalculator.constant_value(stat, base, deviation, item))}
  rescue
    _ -> :error
  end

  defp compute_value(:static, stat, base, deviation, item) do
    {:ok, trunc(Context.ItemStatsCalculator.static_value(stat, base, deviation, item))}
  rescue
    _ -> :error
  end
end
