defmodule Ms2ex.Items.ConstantStats do
  alias Ms2ex.{Item, Items, Lua, Storage}

  def get(%Item{} = item, pick_id, level_factor) do
    constant_id = item.metadata.option.constant_id
    options = Storage.Tables.ItemOptions.find_constant(constant_id, item.rarity)

    if options do
      get_stats(item, options, pick_id, level_factor)
    else
      get_default(item, %{}, pick_id, level_factor)
    end
  end

  defp get_stats(item, options, option_id, level_factor) do
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
      get_default(item, constant_stats, option_id, level_factor)
    else
      constant_stats
    end
  end

  defp get_default(item, constant_stats, option_id, level_factor) do
    base_options = Storage.Tables.ItemOptions.find_pick(option_id, item.rarity)

    if base_options do
      process_options(item, constant_stats, base_options, level_factor)
    else
      constant_stats
    end
  end

  defp process_options(item, constant_stats, base_options, level_factor) do
    Enum.reduce(base_options.constant_value, constant_stats, fn pick, acc ->
      process_stat(item, acc, pick, level_factor)
    end)
  end

  defp process_stat(item, constant_stats, {pick_stat, pick_value}, level_factor) do
    constant_stats =
      if constant_stats[pick_stat] do
        constant_stats
      else
        basic_stat = Items.Stat.build(pick_stat, :flat, 0, :basic)
        Map.put(constant_stats, pick_stat, basic_stat)
      end

    basic_stat = constant_stats[pick_stat]

    value =
      Lua.get_stat_constant_value(
        pick_stat,
        basic_stat.value,
        pick_value,
        item,
        level_factor
      )

    constant_stats =
      if value <= 0.0000 do
        Map.delete(constant_stats, pick_stat)
      else
        constant_stats
      end

    {result, _} = Float.parse("#{value}")

    basic_stat = Map.put(basic_stat, :value, result)
    Map.put(constant_stats, pick_stat, basic_stat)
  end
end
