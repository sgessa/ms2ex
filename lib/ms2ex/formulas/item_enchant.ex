defmodule Ms2ex.Formulas.ItemEnchant do
  @bonus_factors [
    0.02,
    0.04,
    0.07,
    0.1,
    0.14,
    0.19,
    0.25,
    0.32,
    0.4,
    0.5,
    0.64,
    0.84,
    1.12,
    1.5,
    2.0
  ]

  @spec values(integer(), integer(), integer()) :: [integer() | float()]
  def values(enchant_level, item_type, item_level) do
    bonus_factor = Enum.at(@bonus_factors, enchant_level)
    {stat_type1, stat_type2} = stat_types(item_type, item_level)

    [stat_type1, bonus_factor, stat_type2, bonus_factor]
  end

  defp stat_types(item_type, _item_level) when item_type >= 30 and item_type <= 56, do: {27, 28}
  defp stat_types(_item_type, item_level) when item_level > 70, do: {28, 0}
  defp stat_types(_item_type, _item_level), do: {20, 0}
end
