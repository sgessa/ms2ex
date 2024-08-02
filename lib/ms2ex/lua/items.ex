defmodule Ms2ex.Lua.Items do
  alias Ms2ex.{Context, Enums}

  def get_enchant_values(item) do
    script = get_script("calcEnchantValues")

    {:ok, results} =
      :luaport.call(script, :calcEnchantBoostValues, [
        item.enchant_level,
        Enums.ItemType.get_value(Context.Items.type(item)),
        item.metadata.limit.level
      ])

    results
  end

  def get_stat_static_value(pick_attr, stat_value, deviation, item) do
    script = get_script("calcItemValues")

    {:ok, [min, max]} =
      :luaport.call(script, get_pick_attribute(:static, pick_attr), [
        stat_value,
        deviation,
        Enums.ItemType.get_value(Context.Items.type(item)),
        List.first(item.metadata.limit.job_recommends),
        item.metadata.option.level_factor,
        item.rarity,
        item.metadata.limit.level
      ])

    min + (max + 1 - min) * :rand.uniform()
  end

  def get_stat_constant_value(pick_attr, stat_value, deviation, item) do
    script = get_script("calcItemValues")
    item_type = Enums.ItemType.get_value(Context.Items.type(item))

    {:ok, [value]} =
      :luaport.call(script, get_pick_attribute(:constant, pick_attr), [
        stat_value,
        deviation,
        item_type,
        List.first(item.metadata.limit.job_recommends),
        item.metadata.option.level_factor,
        item.rarity,
        item.metadata.limit.level
      ])

    value
  end

  defp get_script(script_name) do
    path = Path.join(["priv", "scripts", "Functions", script_name])

    script_id = script_name |> Macro.underscore() |> String.to_atom()

    case :luaport.spawn(script_id, path) do
      {:ok, script, _args} -> script
      {:error, {:already_started, script}} -> script
    end
  end

  defp get_pick_attribute(:constant, stat) do
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

  defp get_pick_attribute(:static, stat) do
    case stat do
      # Flat
      :health -> :static_value_hp
      :defense -> :static_value_ndd
      :magical_res -> :static_value_mar
      :physical_res -> :static_value_par
      :physical_atk -> :static_value_pap
      :magical_atk -> :static_value_map
      :max_weapon_atk -> :static_value_wapmax
      # Rate
      :perfect_guard -> :static_rate_abp
      _ -> nil
    end
  end
end
