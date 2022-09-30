defmodule Ms2ex.Items.StaticStats do
  alias Ms2ex.{Item, Items, Storage}

  def get(_item, _option_id, level_factor) when level_factor < 50 do
    %{}
  end

  def get(%Item{} = item, option_id, level_factor) do
    static_id = item.metadata.options.static_id
    options = Storage.Items.StaticOptions.lookup(static_id, item.rarity)

    if options do
      get_stats(item, options, option_id, level_factor)
    else
      get_default(item, %{}, option_id, level_factor)
    end
  end

  defp get_stats(item, options, option_id, level_factor) do
    %{stats: stats, special_stats: special_stats} = options

    static_stats = Enum.into(stats, %{}, &{&1.attribute, Items.Stat.build(&1)})
    static_stats = Enum.into(special_stats, static_stats, &{&1.attribute, Items.Stat.build(&1)})

    # TODO: Implement Hidden ndd (defense) and wapmax (Max Weapon Attack)

    get_default(item, static_stats, option_id, level_factor)
  end

  defp get_default(item, static_stats, option_id, level_factor) do
    base_options = Ms2ex.Storage.Items.PickOptions.lookup(option_id, item.rarity)

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



    Enum.reduce(base_options.static_values, static_stats, fn static_pick, acc ->
      calc_script = get_calc_script(static_pick.stat)

      if calc_script do
        process_stat(item, acc, static_pick, calc_script, level_factor, script)
      else
        acc
      end
    end)

    # TO DO: Process static rates
  end

  defp process_stat(item, static_stats, pick, calc_script, level_factor, script) do
    static_stats =
      if static_stats[pick.stat] do
        static_stats
      else
        basic_stat = Items.Stat.build(pick.stat, :flat, 0)
        Map.put(static_stats, pick.stat, basic_stat)
      end

    basic_stat = static_stats[pick.stat]
    stat_value = Map.get(basic_stat, basic_stat.type)

    {:ok, {min, max}} =
      :luaport.call(script, String.to_atom(calc_script), [
        stat_value,
        pick.deviation_value,
        Items.Type.from_name(Items.type(item)),
        List.first(item.metadata.limit.job_recommendations),
        level_factor,
        item.rarity,
        item.level
      ])

    result = Enum.random(min..max)
    basic_stat = Map.put(basic_stat, basic_stat.type, result)

    Map.put(static_stats, pick.stat, basic_stat)
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
