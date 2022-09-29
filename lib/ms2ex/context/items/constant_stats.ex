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
    base_options = Ms2ex.Metadata.Items.Options.Picks.lookup(option_id, item.rarity)

    if base_options do
      process_options(item, constant_stats, base_options, level_factor)
    else
      constant_stats
    end
  end

  defp process_options(item, constant_stats, base_options, option_level_factor) do
    {:ok, script, []} = :luaport.spawn(:myid, "priv/scripts/Functions/calcItemValues")

    Enum.reduce(base_options.constants, constant_stats, fn constant_pick, acc ->
      calc_script = get_calc_script(constant_pick.stat)

      acc =
        if acc[constant_pick.stat] do
          acc
        else
          basic_stat = Items.Stat.build(constant_pick.stat, :flat, 0)
          Map.put(acc, constant_pick.stat, basic_stat)
        end

      basic_stat = acc[constant_pick.stat]
      stat_value = Map.get(basic_stat, basic_stat.type)

      {:ok, result} =
        :luaport.call(script, String.to_atom(calc_script), [
          stat_value,
          constant_pick.deviation_value,
          item.type,
          List.first(item.metadata.job_recommendations),
          option_level_factor,
          item.rarity,
          item.level
        ])

      acc =
        if result.number <= 0.0000 do
          Map.delete(acc, constant_pick.stat)
        else
          acc
        end

      # TODO make sure result.number is a float
      basic_stat = Map.put(basic_stat, basic_stat.type, result.number)

      Map.put(acc, constant_pick.stat, basic_stat)
    end)
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
