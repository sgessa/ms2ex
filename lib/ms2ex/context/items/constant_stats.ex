defmodule Ms2ex.Items.ConstantStats do
  alias Ms2ex.{Item, Items, Storage}

  def get(%Item{} = item, option_id, level_factor) do
    constant_id = item.metadata.options.constant_id
    options = Storage.Items.ConstantOptions.lookup(constant_id, item.rarity)

    if options do
      get_stats(item, options, option_id, level_factor)
    else
      get_default(item, %{}, option_id, level_factor)
    end
  end

  defp get_stats(item, options, option_id, level_factor) do
    %{stats: stats, special_stats: special_stats} = options

    constant_stats = Enum.into(stats, %{}, &{&1.attribute, Items.Stat.build(&1)})

    constant_stats =
      Enum.into(special_stats, constant_stats, &{&1.attribute, Items.Stat.build(&1)})

    # TODO Implement Hidden ndd (defense) and wapmax (Max Weapon Attack)

    if level_factor > 50 do
      get_default(item, constant_stats, option_id, level_factor)
    else
      constant_stats
    end
  end

  defp get_default(item, constant_stats, option_id, level_factor) do
    base_options = Ms2ex.Storage.Items.PickOptions.lookup(option_id, item.rarity)

    if base_options do
      process_options(item, constant_stats, base_options, level_factor)
    else
      constant_stats
    end
  end

  defp process_options(item, constant_stats, base_options, level_factor) do
    Enum.reduce(base_options.constants, constant_stats, fn constant_pick, acc ->
      calc_script = get_calc_script(constant_pick.stat)

      if calc_script do
        process_stat(item, acc, constant_pick, calc_script, level_factor)
      else
        acc
      end
    end)
  end

  defp process_stat(item, constant_stats, pick, calc_script, level_factor) do
    script =
      case :luaport.spawn(:calc_item_values, "priv/scripts/Functions/calcItemValues") do
        {:ok, script, _args} -> script
        {:error, {:already_started, script}} -> script
      end

    constant_stats =
      if constant_stats[pick.stat] do
        constant_stats
      else
        basic_stat = Items.Stat.build(pick.stat, :flat, 0)
        Map.put(constant_stats, pick.stat, basic_stat)
      end

    basic_stat = constant_stats[pick.stat]
    stat_value = Map.get(basic_stat, basic_stat.type)

    {:ok, [result]} =
      :luaport.call(script, String.to_atom(calc_script), [
        stat_value,
        pick.deviation_value,
        Items.Type.from_name(Items.type(item)),
        List.first(item.metadata.limit.job_recommendations),
        level_factor,
        item.rarity,
        1
      ])

    IO.inspect("Got")
    IO.inspect(result)

    constant_stats =
      if result <= 0.0000 do
        Map.delete(constant_stats, pick.stat)
      else
        constant_stats
      end

    # TODO make sure result.number is a float
    basic_stat = Map.put(basic_stat, basic_stat.type, result)

    Map.put(constant_stats, pick.stat, basic_stat)
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
      :magic_atk -> "constant_value_map"
      :min_weapon_atk -> "constant_value_wapmin"
      :max_weapon_atk -> "constant_value_wapmax"
      _ -> nil
    end
  end
end
