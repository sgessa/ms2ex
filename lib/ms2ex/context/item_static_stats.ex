defmodule Ms2ex.Context.ItemStaticStats do
  alias Ms2ex.{Enums, Lua, Schema, Storage, Types}

  def get(%Schema.Item{} = item, pick_id, level_factor) do
    static_id = item.metadata.option.static_id
    options = Storage.Tables.ItemOptions.find_static(static_id, item.rarity)

    if options do
      get_static_stats(item, options, pick_id, level_factor)
    else
      get_pick_stats(item, %{}, pick_id, level_factor)
    end
  end

  defp get_static_stats(item, static_options, pick_id, level_factor) do
    %{num_pick: picks, entries: entries} = static_options

    pick_count = Enum.random(picks.min..picks.max)

    static_stats =
      Enum.map(entries, &process_static_stat(&1))
      |> Enum.take_random(pick_count)
      |> Enum.map(&{&1.attribute, &1})
      |> Map.new()

    get_pick_stats(item, static_stats, pick_id, level_factor)
  end

  # Flat Basic
  defp process_static_stat(%{values: values, basic_attribute: attr}) do
    value = Enum.random(values.min..values.max)
    Types.ItemStat.build(Enums.BasicStatType.get_key(attr), :basic, value, :flat)
  end

  # Rates Basic
  defp process_static_stat(%{rates: values, basic_attribute: attr}) do
    value = :rand.uniform() * (values.max - values.min) + values.max
    Types.ItemStat.build(Enums.BasicStatType.get_key(attr), :basic, value, :rate)
  end

  # Flat Special
  defp process_static_stat(%{values: values, special_attribute: attr}) do
    value = Enum.random(values.min..values.max)
    Types.ItemStat.build(Enums.SpecialStatType.get_key(attr), :special, value, :flat)
  end

  # Rate Special
  defp process_static_stat(%{rates: values, special_attribute: attr}) do
    value = :rand.uniform() * (values.max - values.min) + values.max
    Types.ItemStat.build(Enums.SpecialStatType.get_key(attr), :special, value, :rate)
  end

  defp get_pick_stats(item, static_stats, pick_id, level_factor) do
    pick_options =
      Storage.Tables.ItemOptions.find_pick(pick_id, item.rarity)

    if pick_options do
      process_pick_options(item, static_stats, pick_options, level_factor)
    else
      static_stats
    end
  end

  defp process_pick_options(item, static_stats, pick_options, level_factor) do
    static_stats =
      Enum.reduce(pick_options.static_value, static_stats, fn pick, acc ->
        process_pick_stat(item, acc, :flat, pick, level_factor)
      end)

    Enum.reduce(pick_options.static_rate, static_stats, fn pick, acc ->
      process_pick_stat(item, acc, :rate, pick, level_factor)
    end)
  end

  defp process_pick_stat(item, static_stats, type, {pick_stat, pick_value}, level_factor) do
    # Initialize empty stat if not already present from static options
    static_stats =
      Map.put_new(static_stats, pick_stat, Types.ItemStat.build(pick_stat, type, 0, :basic))

    static_stat = static_stats[pick_stat]

    value =
      Lua.Items.get_stat_static_value(
        pick_stat,
        static_stat.value,
        pick_value,
        item,
        level_factor
      )

    # Put / update static stat
    Map.put(static_stats, pick_stat, %{static_stat | value: value})
  end
end
