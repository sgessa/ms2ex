defmodule Ms2ex.Context.ItemConstantStats do
  alias Ms2ex.{Lua, Schema, Storage, Types}

  def get(%Schema.Item{} = item, pick_options) do
    item.metadata.option.constant_id
    |> Storage.Tables.ItemOptions.find_constant(item.rarity)
    |> get_constant_stats()
    |> get_pick_stats(item, pick_options)
  end

  defp get_constant_stats(nil), do: %{}

  defp get_constant_stats(options) do
    values =
      Enum.into(options.values, [], fn {name, value} ->
        {name, Types.ItemStat.build(name, :flat, value, :basic)}
      end)

    rates =
      Enum.into(options.rates, [], fn {name, value} ->
        {name, Types.ItemStat.build(name, :rate, value, :basic)}
      end)

    special_values =
      Enum.into(options.special_values, [], fn {name, value} ->
        {name, Types.ItemStat.build(name, :flat, value, :special)}
      end)

    special_rates =
      Enum.into(options.special_rates, [], fn {name, value} ->
        {name, Types.ItemStat.build(name, :rate, value, :special)}
      end)

    Map.new(values ++ rates ++ special_values ++ special_rates)
  end

  defp get_pick_stats(constant_stats, _item, nil), do: constant_stats

  defp get_pick_stats(constant_stats, item, pick_options) do
    Enum.reduce(pick_options.constant_value, constant_stats, fn pick, acc ->
      process_pick_stat(item, acc, pick)
    end)
  end

  defp process_pick_stat(item, constant_stats, {pick_stat, pick_value}) do
    # Initialize empty stat if not already present from constant options (always flat)
    constant_stats =
      Map.put_new(constant_stats, pick_stat, Types.ItemStat.build(pick_stat, :flat, 0, :basic))

    constant_stat = constant_stats[pick_stat]

    value =
      Lua.Items.get_stat_constant_value(
        pick_stat,
        constant_stat.value,
        pick_value,
        item
      )

    # Put / update constant stat (if valid value)
    if value <= 0.0,
      do: Map.delete(constant_stats, pick_stat),
      else: Map.put(constant_stats, pick_stat, %{constant_stat | value: value})
  end
end
