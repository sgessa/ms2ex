defmodule Ms2ex.Lua do
  alias Ms2ex.Items

  def get_stat_constant_value(stat, stat_value, deviation, item, lvl_factor) do
    script = get_script("calcItemValues")
    const_value = get_constant(stat)

    {:ok, [stat_value]} =
      :luaport.call(script, const_value, [
        stat_value,
        deviation,
        Items.Type.value(Items.type(item)),
        List.first(item.metadata.limit.job_recommends),
        lvl_factor,
        item.rarity,
        item.level
      ])

    stat_value
  end

  defp get_script(script_name) do
    path = Path.join(["priv", "scripts", "Functions", script_name])

    case :luaport.spawn(:calc_item_values, path) do
      {:ok, script, _args} -> script
      {:error, {:already_started, script}} -> script
    end
  end

  defp get_constant(stat) do
    case stat do
      :health -> :constant_value_hp
      :defense -> :constant_value_ndd
      :magical_res -> :constant_value_mar
      :physical_res -> :constant_value_par
      :critical_rate -> :constant_value_cap
      :strength -> :constant_value_str
      :dexterity -> :constant_value_dex
      :intelligence -> :constant_value_int
      :luck -> :constant_value_luk
      :magical_atk -> :constant_value_map
      :min_weapon_atk -> :constant_value_wapmin
      :max_weapon_atk -> :constant_value_wapmax
      _ -> nil
    end
  end
end
