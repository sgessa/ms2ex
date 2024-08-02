defmodule Ms2ex.Items.ConstantStats do
  alias Ms2ex.{Item, Items, Storage}

  def get(%Item{} = item, pick_id, level_factor) do
    constant_id = item.metadata.option.constant_id
    options = Storage.Tables.ItemOptions.find_constant(constant_id, item.rarity)

    if options do
      get_constant_stats(item, options, pick_id, level_factor)
    else
      get_pick_stats(item, %{}, pick_id, level_factor)
    end
  end

  defp get_constant_stats(item, options, pick_id, level_factor) do
    values =
      Enum.into(options.values, [], fn {name, value} ->
        {name, Items.Stat.build(name, :flat, value, :basic)}
      end)

    rates =
      Enum.into(options.rates, [], fn {name, value} ->
        {name, Items.Stat.build(name, :rate, value, :basic)}
      end)

    special_values =
      Enum.into(options.special_values, [], fn {name, value} ->
        {name, Items.Stat.build(name, :flat, value, :special)}
      end)

    special_rates =
      Enum.into(options.special_rates, [], fn {name, value} ->
        {name, Items.Stat.build(name, :rate, value, :special)}
      end)

    constant_stats = Map.new(values ++ rates ++ special_values ++ special_rates)

    if level_factor > 50 do
      get_pick_stats(item, constant_stats, pick_id, level_factor)
    else
      constant_stats
    end

    constant_stats
  end

  defp get_pick_stats(item, constant_stats, pick_id, level_factor) do
    pick_options = Storage.Tables.ItemOptions.find_pick(pick_id, item.rarity)

    if pick_options do
      process_pick_options(item, constant_stats, pick_options, level_factor)
    else
      constant_stats
    end
  end

  defp process_pick_options(item, constant_stats, pick_options, level_factor) do
    Enum.reduce(pick_options.constant_value, constant_stats, fn pick, acc ->
      process_pick_stat(item, acc, pick, level_factor)
    end)
  end

  defp process_pick_stat(item, constant_stats, {pick_stat, pick_value}, level_factor) do
    # Initialize empty stat if not already present from constant options (always flat)
    constant_stats =
      Map.put_new(constant_stats, pick_stat, Items.Stat.build(pick_stat, :flat, 0, :basic))

    constant_stat = constant_stats[pick_stat]

    value =
      Items.Lua.get_stat_constant_value(
        pick_stat,
        constant_stat.value,
        pick_value,
        item,
        level_factor
      )

    {result, _} = Float.parse("#{value}")

    # Put / update constant stat (if valid value)
    if result <= 0.0,
      do: Map.delete(constant_stats, pick_stat),
      else: Map.put(constant_stats, pick_stat, %{constant_stat | value: result})
  end
end
