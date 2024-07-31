defmodule Ms2ex.Items.ConstantStats do
  alias Ms2ex.{Item, Items}
  alias Ms2ex.Storage

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
    script =
      case :luaport.spawn(:calc_item_values, "priv/scripts/Functions/calcItemValues") do
        {:ok, script, _args} -> script
        {:error, {:already_started, script}} -> script
      end

    Enum.reduce(base_options.constant_value, constant_stats, fn {stat, _v} = pick, acc ->
      calc_script = get_calc_script(stat)

      if calc_script do
        process_stat(item, acc, pick, calc_script, level_factor, script)
      else
        acc
      end
    end)
  end

  defp process_stat(item, constant_stats, {p_stat, p_value}, calc_script, level_factor, script) do
    constant_stats =
      if constant_stats[p_stat] do
        constant_stats
      else
        basic_stat = Items.Stat.build(p_stat, :flat, 0, :basic)
        Map.put(constant_stats, p_stat, basic_stat)
      end

    basic_stat = constant_stats[p_stat]

    {:ok, [result]} =
      :luaport.call(script, String.to_atom(calc_script), [
        basic_stat.value,
        p_value,
        Items.Type.value(Items.type(item)),
        List.first(item.metadata.limits.job_recommends),
        level_factor,
        item.rarity,
        item.level
      ])

    constant_stats =
      if result <= 0.0000 do
        Map.delete(constant_stats, p_stat)
      else
        constant_stats
      end

    {result, _} = Float.parse("#{result}")
    basic_stat = Map.put(basic_stat, :value, result)

    Map.put(constant_stats, p_stat, basic_stat)
  end

  defp get_calc_script(stat) do
    case stat do
      :hp -> "constant_value_hp"
      :defense -> "constant_value_ndd"
      :magic_res -> "constant_value_mar"
      :physical_res -> "constant_value_par"
      :crit_rate -> "constant_value_cap"
      :str -> "constant_value_str"
      :dex -> "constant_value_dex"
      :int -> "constant_value_int"
      :luk -> "constant_value_luk"
      :magic_attk -> "constant_value_map"
      :min_weapon_attk -> "constant_value_wapmin"
      :max_weapon_attk -> "constant_value_wapmax"
      _ -> nil
    end
  end
end
