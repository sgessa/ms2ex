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

  # TODO get from script
  defp get_default(item, constant_stats, option_id, _level_factor) do
    base_options = Ms2ex.Metadata.Items.Options.Picks.lookup(option_id, item.rarity)

    {:ok, pid, []} = :luaport.spawn(:myid, "priv/scripts/Functions/calcItemValues")

    Enum.map(base_options.constants, fn base_constant ->
      case get_base_constant_fun(base_constant.stat) do
        nil ->
          base_constant
        fun ->
          {:ok, _result} = :luaport.call(pid, String.to_atom(fun), base_constant.stat)
      end
    end)

    constant_stats
  end

  defp get_base_constant_fun(stat) do
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
