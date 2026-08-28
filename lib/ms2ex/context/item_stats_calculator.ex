defmodule Ms2ex.Context.ItemStatsCalculator do
  alias Ms2ex.Context
  alias Ms2ex.Enums
  alias Ms2ex.Formulas.ItemBasicStats
  alias Ms2ex.Formulas.ItemDefense
  alias Ms2ex.Formulas.ItemRates
  alias Ms2ex.Formulas.ItemStaticStats
  alias Ms2ex.Formulas.ItemWeaponAttack

  @constant_stats %{
    health: :constant_value_hp,
    defense: :constant_value_ndd,
    magical_res: :constant_value_mar,
    physical_res: :constant_value_par,
    critical_rate: :constant_value_cap,
    strength: :constant_value_str,
    dexterity: :constant_value_dex,
    intelligence: :constant_value_int,
    luck: :constant_value_luk,
    magical_atk: :constant_value_map,
    min_weapon_atk: :constant_value_wapmin,
    max_weapon_atk: :constant_value_wapmax
  }

  @static_stats %{
    health: :static_value_hp,
    defense: :static_value_ndd,
    magical_res: :static_value_mar,
    physical_res: :static_value_par,
    physical_atk: :static_value_pap,
    magical_atk: :static_value_map,
    max_weapon_atk: :static_value_wapmax,
    perfect_guard: :static_rate_abp
  }

  def constant_stats, do: @constant_stats
  def static_stats, do: @static_stats

  def allowed_stats(:constant), do: @constant_stats
  def allowed_stats(:static), do: @static_stats

  def constant_value(:min_weapon_atk, stat_value, deviation, item),
    do: weapon_attack_value(:min, stat_value, deviation, item)

  def constant_value(:max_weapon_atk, stat_value, deviation, item),
    do: weapon_attack_value(:max, stat_value, deviation, item)

  def constant_value(:defense, stat_value, deviation, item) do
    ItemDefense.constant(
      stat_value,
      deviation,
      item_type(item),
      first_recommended_job(item),
      item.metadata.option.level_factor,
      item.rarity,
      item.metadata.limit.level
    )
  end

  def constant_value(stat, stat_value, deviation, item)
      when stat in [
             :health,
             :strength,
             :dexterity,
             :intelligence,
             :luck,
             :critical_rate,
             :magical_atk,
             :magical_res,
             :physical_res
           ] do
    ItemBasicStats.constant(
      stat,
      stat_value,
      deviation,
      item_type(item),
      first_recommended_job(item),
      item.metadata.option.level_factor,
      item.rarity,
      item.metadata.limit.level,
      if(stat == :intelligence, do: 1, else: 0)
    )
  end

  def constant_value(stat, _stat_value, _deviation, _item),
    do: raise(ArgumentError, "unsupported constant item stat: #{inspect(stat)}")

  def static_value(:max_weapon_atk, stat_value, deviation, item) do
    item
    |> static_weapon_attack_value(stat_value, deviation)
    |> roll_value()
  end

  def static_value(:perfect_guard, stat_value, _deviation, item) do
    ItemRates.static_perfect_guard(stat_value, item.metadata.option.level_factor)
    |> roll_value()
  end

  def static_value(stat, stat_value, _deviation, item)
      when stat in [:health, :physical_atk, :magical_atk, :physical_res, :magical_res] do
    ItemStaticStats.value(stat, stat_value, item.metadata.option.level_factor, item_type(item))
    |> roll_value()
  end

  def static_value(:defense, stat_value, _deviation, item) do
    ItemDefense.static(
      stat_value,
      item_type(item),
      first_recommended_job(item),
      item.metadata.option.level_factor,
      item.rarity,
      item.metadata.limit.level
    )
    |> roll_value()
  end

  def static_value(stat, _stat_value, _deviation, _item),
    do: raise(ArgumentError, "unsupported static item stat: #{inspect(stat)}")

  defp weapon_attack_value(bound, stat_value, deviation, item) do
    ItemWeaponAttack.constant_value(
      bound,
      stat_value,
      deviation,
      item_type(item),
      0,
      item.metadata.option.level_factor,
      item.rarity,
      item.metadata.limit.level
    )
  end

  defp static_weapon_attack_value(item, stat_value, deviation) do
    ItemWeaponAttack.static_value(
      :max,
      stat_value,
      deviation,
      item_type(item),
      0,
      item.metadata.option.level_factor,
      item.rarity,
      item.metadata.limit.level
    )
  end

  defp roll_value({minimum, maximum}),
    do: minimum + (maximum + 1 - minimum) * :rand.uniform()

  defp first_recommended_job(item) do
    item.metadata.limit
    |> Map.get(:job_limits, [])
    |> List.first() || 0
  end

  defp item_type(item) do
    item.item_id
    |> Context.ItemTypes.get_type_by_item_id()
    |> Enums.ItemType.get_value()
  end
end
