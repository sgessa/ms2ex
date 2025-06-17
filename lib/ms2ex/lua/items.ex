defmodule Ms2ex.Lua.Items do
  alias Ms2ex.{Context, Enums}

  def get_enchant_values(item) do
    script = get_script("calcEnchantValues")

    {:ok, results} =
      :luaport.call(script, :calcEnchantBoostValues, [
        item.enchant_level,
        get_item_type(item.item_id),
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
        get_item_type(item.item_id),
        List.first(item.metadata.limit.job_recommends),
        item.metadata.option.level_factor,
        item.rarity,
        item.metadata.limit.level
      ])

    min + (max + 1 - min) * :rand.uniform()
  end

  def get_stat_constant_value(pick_attr, stat_value, deviation, item) do
    script = get_script("calcItemValues")

    {:ok, [value]} =
      :luaport.call(script, get_pick_attribute(:constant, pick_attr), [
        stat_value,
        deviation,
        get_item_type(item.item_id),
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

  @static_constant_stats %{
    health: :constant_value_hp,
    defense: :constant_value_ndd,
    magical_res: :constant_value_mar,
    physical_res: :constant_value_par,
    critical_rate: :constant_value_cap,
    strength: :constant_value_str,
    dexterity: :constant_value_dex,
    intelligence: :constant_value_int,
    luck: :constant_value_luk,
    physical_atk: :constant_value_pap,
    magical_atk: :constant_value_map,
    min_weapon_atk: :constant_value_wapmin,
    max_weapon_atk: :constant_value_wapmax
  }
  defp get_pick_attribute(:constant, stat) do
    Map.get(@static_constant_stats, stat)
  end

  @static_constant_stats %{
    health: :static_value_hp,
    defense: :static_value_ndd,
    magical_res: :static_value_mar,
    physical_res: :static_value_par,
    physical_atk: :static_value_pap,
    magical_atk: :static_value_map,
    max_weapon_atk: :static_value_wapmax,
    perfect_guard: :static_rate_abp
  }
  defp get_pick_attribute(:static, stat) do
    Map.get(@static_constant_stats, stat)
  end

  defp get_item_type(item_id) do
    item_id
    |> Context.ItemTypes.get_type_by_item_id()
    |> Enums.ItemType.get_value()
  end
end
