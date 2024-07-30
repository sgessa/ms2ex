defmodule Ms2ex.Items.StaticStats do
  alias Ms2ex.{Item, Items}
  alias Ms2ex.Storage

  def get(_item, _option_id, level_factor) when level_factor < 50 do
    %{}
  end

  def get(%Item{} = item, option_id, level_factor) do
    static_id = item.metadata.option.static_id
    options = Storage.Tables.Items.Options.find_static(static_id, item.rarity)

    if options do
      get_stats(item, options, option_id, level_factor)
    else
      get_default(item, %{}, option_id, level_factor)
    end
  end

  # TODO: Rewrite (similar to RandomOption)
  # Data structure changed
  # iex> Ms2ex.Metadata.get(Ms2ex.Metadata.Table, "itemoptionstatic.xml") |> Map.get(:table) |> Map.get(:options) |> Map.get("11300011") |> Map.get("5")

  defp get_stats(item, options, option_id, level_factor) do
    %{stats: stats, special_stats: special_stats} = options

    static_stats = Enum.into(stats, %{}, &{&1.attribute, Items.Stat.build(&1, :basic)})

    static_stats =
      Enum.into(special_stats, static_stats, &{&1.attribute, Items.Stat.build(&1, :special)})

    # TODO: Implement Hidden ndd (defense) and wapmax (Max Weapon Attack)

    get_default(item, static_stats, option_id, level_factor)
  end

  defp get_default(item, static_stats, option_id, level_factor) do
    base_options = Storage.Tables.Items.Options.find_pick(option_id, item.rarity)

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
        List.first(item.metadata.limits.job_recommendations),
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
