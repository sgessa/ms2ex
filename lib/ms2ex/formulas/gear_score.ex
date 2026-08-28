defmodule Ms2ex.Formulas.GearScore do
  @ranked_types [13, 14, 15, 16, 17, 22, 30, 31, 32, 33, 34, 40, 41, 50, 51, 52, 53, 54, 55, 56]
  @rank_factors %{1 => 1.0, 2 => 1.0, 3 => 1.0, 4 => 0.558, 5 => 1.2, 6 => 1.9}
  @level_factors %{
    57 => 2.899,
    60 => 3.4442,
    67 => 12.538,
    70 => 14.15,
    80 => 45.91,
    90 => 140.13
  }
  @accessory_types [12, 18, 19, 20]
  @common_coefficients [
    0.0,
    0.02,
    0.04,
    0.06,
    0.08,
    0.1,
    0.14,
    0.18,
    0.23,
    0.29,
    0.44,
    0.74,
    1.05,
    1.36,
    1.68,
    2.0
  ]
  @na_coefficients [
    0.0,
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
  @r5_coefficients [
    0.0,
    0.02,
    0.04,
    0.06,
    0.08,
    0.1,
    0.14,
    0.18,
    0.23,
    0.29,
    0.35,
    0.41,
    0.47,
    0.53,
    0.59,
    0.65
  ]
  @l70_coefficients [
    0.0,
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
    0.525,
    0.655,
    0.707,
    0.772,
    0.88
  ]
  @armor_coefficients %{13 => 0.21, 14 => 0.32, 15 => 0.3, 16 => 0.06, 17 => 0.06, 22 => 0.62}
  @accessory_coefficients %{12 => 0.2, 18 => 0.2, 19 => 0.2, 20 => 0.2, 21 => 0.2}

  @doc "Calculates one item's base and enchant Gear Score components."
  @spec item_level(number(), integer(), integer(), integer(), integer()) :: {integer(), integer()}
  def item_level(gear_score, rarity, item_type, enchant_level, limit_break_level) do
    enchant_level = enchant_level |> trunc() |> clamp(0, 15)
    base = base_score(gear_score, rarity, item_type, limit_break_level)
    enchant = base * enchant_coefficient(rarity, gear_score, enchant_level, limit_break_level)

    {trunc(base), trunc(enchant)}
  end

  @doc "Calculates total Gear Score for item maps containing the formula inputs."
  @spec calculate([map()]) :: integer()
  def calculate(items) do
    Enum.reduce(items, 0, fn item, total ->
      total + item_score(item)
    end)
  end

  defp item_score(%{item_type: item_type}) when item_type in [40, 41], do: 0

  defp item_score(item) do
    {base, enchant} =
      item_level(
        Map.get(item, :gear_score, 0),
        Map.get(item, :rarity, 0),
        Map.get(item, :item_type, 0),
        Map.get(item, :enchant_level, 0),
        Map.get(item, :limit_break_level, 0)
      )

    score = base + enchant
    if Map.get(item, :item_type) in [31, 34], do: div(score, 2), else: score
  end

  defp base_score(gear_score, rarity, item_type, limit_break_level) do
    gear_score = max(gear_score, 0)

    cond do
      gear_score == 0 -> 0.0
      limit_break_level < 60 -> pre_limit_break_score(gear_score, rarity, item_type)
      limit_break_level < 70 -> limit_break_score(gear_score, rarity, item_type)
      true -> 0.0
    end
  end

  defp pre_limit_break_score(gear_score, rarity, item_type) do
    if high_rank?(gear_score, rarity) and ranked_or_accessory?(item_type) do
      (2 + Map.get(@level_factors, gear_score, 0.0)) * 1030 * rank_factor(rarity) *
        item_coefficient(item_type)
    else
      basic_score(gear_score, rarity, item_type)
    end
  end

  defp limit_break_score(gear_score, rarity, item_type) do
    if high_rank?(gear_score, rarity) and ranked_or_accessory?(item_type) do
      grade_offset =
        if item_type in @accessory_types, do: max(rarity - 2, 0), else: max(rarity - 1, 0)

      base =
        (10 * gear_score + grade_offset * 5) * item_coefficient(item_type) * 2 *
          max(rarity - 3, 1)

      base + max(gear_score - 50, 0) * 100 * item_coefficient(item_type)
    else
      basic_score(gear_score, rarity, item_type)
    end
  end

  defp basic_score(gear_score, rarity, item_type),
    do: (10 * gear_score + max(rarity - 1, 0) * 5) * item_coefficient(item_type)

  defp enchant_coefficient(rarity, gear_score, enchant_level, limit_break_level) do
    coefficients =
      cond do
        limit_break_level < 60 ->
          pre_limit_break_coefficients(rarity)

        limit_break_level < 70 ->
          if(rarity >= 4, do: @r5_coefficients, else: @common_coefficients)

        limit_break_level < 80 ->
          limit_break_coefficients(rarity, gear_score)

        rarity >= 4 ->
          @na_coefficients

        true ->
          @common_coefficients
      end

    coefficient(coefficients, enchant_level)
  end

  defp pre_limit_break_coefficients(rarity),
    do: if(rarity >= 4, do: @na_coefficients, else: @common_coefficients)

  defp limit_break_coefficients(4, gear_score) when gear_score < 70, do: @r5_coefficients
  defp limit_break_coefficients(4, _gear_score), do: @l70_coefficients
  defp limit_break_coefficients(rarity, _gear_score) when rarity > 4, do: @na_coefficients
  defp limit_break_coefficients(_rarity, _gear_score), do: @common_coefficients

  defp coefficient(coefficients, enchant_level), do: Enum.at(coefficients, enchant_level, 0.0)
  defp high_rank?(gear_score, rarity), do: rarity > 3 and gear_score >= 50

  defp ranked_or_accessory?(item_type),
    do: item_type in @ranked_types or item_type in @accessory_types

  defp rank_factor(rarity), do: Map.get(@rank_factors, rarity, 1.0)

  defp item_coefficient(item_type) do
    cond do
      item_type in @armor_coefficients -> Map.fetch!(@armor_coefficients, item_type)
      item_type in @accessory_coefficients -> Map.fetch!(@accessory_coefficients, item_type)
      item_type in @ranked_types -> 1.0
      true -> 0.0
    end
  end

  defp clamp(value, minimum, maximum), do: value |> max(minimum) |> min(maximum)
end
