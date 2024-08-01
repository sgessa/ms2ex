defmodule Ms2ex.Items.StaticStats do
  alias Ms2ex.{Item, Items, Enums}
  alias Ms2ex.Storage

  def get(%Item{} = item, option_id, level_factor) do
    static_id = item.metadata.option.static_id
    options = Storage.Tables.ItemOptions.find_static(static_id, item.rarity)

    if options do
      get_stats(item, options, option_id, level_factor)
    else
      get_default(item, %{}, option_id, level_factor)
    end
  end

  defp get_stats(item, static_options, option_id, level_factor) do
    %{num_pick: picks, entries: entries} = static_options

    pick_count = Enum.random(picks.min..picks.max)

    static_stats =
      Enum.map(entries, &process_stat(&1))
      |> Enum.take_random(pick_count)
      |> Enum.map(&{&1.attribute, &1})
      |> Map.new()

    get_default(item, static_stats, option_id, level_factor)
  end

  defp process_stat(%{values: values, basic_attribute: attr}) do
    value = Enum.random(values.min..values.max)
    Items.Stat.build(Enums.BasicStatType.get_key(attr), :basic, value, :flat)
  end

  defp process_stat(%{rates: values, basic_attribute: attr}) do
    value = :rand.uniform() * (values.max - values.min) + values.max
    Items.Stat.build(Enums.BasicStatType.get_key(attr), :basic, value, :rate)
  end

  defp process_stat(%{values: values, special_attribute: attr}) do
    value = Enum.random(values.min..values.max)
    Items.Stat.build(Enums.SpecialStatType.get_key(attr), :special, value, :flat)
  end

  defp process_stat(%{rates: values, special_attribute: attr}) do
    value = :rand.uniform() * (values.max - values.min) + values.max
    Items.Stat.build(Enums.SpecialStatType.get_key(attr), :special, value, :rate)
  end

  defp get_default(item, static_stats, option_id, level_factor) do
    base_options =
      Storage.Tables.ItemOptions.find_pick(option_id, item.rarity)

    if base_options do
      process_options(item, static_stats, base_options, level_factor)
    else
      static_stats
    end
  end

  defp process_options(item, static_stats, base_options, level_factor) do
    script =
      case :luaport.spawn(:calc_item_values, "priv/scripts/Functions/calcItemValues") do
        {:ok, script, _args} -> script
        {:error, {:already_started, script}} -> script
      end

    static_stats
    |> set_stats(item, base_options.static_value, level_factor, script)
    |> set_stats(item, base_options.static_rate, level_factor, script)
  end

  defp set_stats(static_stats, item, options, level_factor, script) do
    Enum.reduce(options, static_stats, fn {p_name, _val} = pick, acc ->
      calc_script = get_calc_script(p_name)

      if calc_script do
        set_stat(item, acc, pick, calc_script, level_factor, script)
      else
        acc
      end
    end)
  end

  defp set_stat(item, static_stats, {p_name, p_value}, calc_script, level_factor, script) do
    static_stats =
      if static_stats[p_name] do
        static_stats
      else
        basic_stat = Items.Stat.build(p_name, :flat, 0, :basic)
        Map.put(static_stats, p_name, basic_stat)
      end

    basic_stat = static_stats[p_name]

    {:ok, [min, max]} =
      :luaport.call(script, String.to_atom(calc_script), [
        basic_stat.value,
        p_value,
        Items.Type.value(Items.type(item)),
        List.first(item.metadata.limit.job_recommends),
        level_factor,
        item.rarity,
        item.level
      ])

    random = min + (max - min) * :rand.uniform()
    basic_stat = Map.put(basic_stat, :value, random)

    Map.put(static_stats, p_name, basic_stat)
  end

  defp get_calc_script(stat) do
    case stat do
      :hp -> "static_value_hp"
      :defense -> "static_value_ndd"
      :magic_res -> "static_value_mar"
      :physical_res -> "static_value_par"
      :physical_attk -> "static_value_pap"
      :magic_attk -> "static_value_map"
      :perfect_guard -> "static_rate_abp"
      :max_weapon_attk -> "static_value_wapmax"
      _ -> nil
    end
  end
end
