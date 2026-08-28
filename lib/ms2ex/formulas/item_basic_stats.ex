defmodule Ms2ex.Formulas.ItemBasicStats do
  def constant(stat, _base, _deviation, item_type, job, factor, grade, level, p7 \\ 0) do
    cond do
      stat == :magical_atk -> magical_attack(level, grade)
      stat == :magical_res -> resistance(:magical, item_type, level, grade)
      stat == :physical_res -> resistance(:physical, item_type, level, grade)
      stat == :health -> health(item_type, level, grade, factor)
      stat == :critical_rate -> critical_rate(item_type, grade)
      stat in [:strength, :dexterity, :intelligence, :luck] -> primary(stat, item_type, job, level, p7)
      true -> 0
    end
  end

  defp health(type, level, grade, factor) when type in [12, 18, 19, 20, 21] and factor > 50 do
    value =
      cond do
        level < 60 and grade == 4 -> 360 * 0.6 * :math.pow(1.06, factor - 50)
        level < 60 and grade == 5 -> 600 * 0.6 * :math.pow(1.06, factor - 50)
        level < 60 and grade >= 6 -> 757.44 * 0.6 * :math.pow(1.06, factor - 50)
        level >= 60 and grade == 4 -> 360 * 0.6 * :math.pow(1.06, factor - (53 + (factor / 10 - 6) * 6))
        level >= 60 and grade == 5 -> 600 * 0.6 * :math.pow(1.06, factor - (53 + (factor / 10 - 6) * 6))
        level >= 60 and grade >= 6 -> 757.44 * 0.6 * :math.pow(1.06, factor - (53 + (factor / 10 - 6) * 6))
        true -> (factor - 50) / 2 * 13
      end

    round_value(value)
  end

  defp health(type, _level, grade, factor) when type > 30 and type < 40 and factor > 5, do: round_value(1.2884 * factor - 6.56 * hp_grade(grade) * hp_slot(type))
  defp health(type, _level, grade, factor) when type > 49 and type < 60 and factor > 5, do: round_value(1.2884 * factor - 6.56 * hp_grade(grade) * hp_slot(type) * 2)
  defp health(type, _level, _grade, factor) when type > 30 and type < 40 and factor < 6, do: 1
  defp health(type, _level, _grade, factor) when type > 49 and type < 60 and factor < 6, do: 2
  defp health(_, _, _, _), do: 0

  defp hp_grade(grade), do: %{1 => 0.3, 2 => 0.4, 3 => 0.5, 4 => 0.6, 5 => 0.7, 6 => 0.8}[grade] || 0
  defp hp_slot(type), do: %{30 => 0.1, 31 => 0.3, 32 => 0.04, 33 => 0.1, 34 => 0.3, 50 => 0.2, 51 => 0.1, 52 => 0.1, 53 => 0.2, 54 => 0.1, 55 => 0.1, 56 => 0.2}[type] || 0

  defp magical_attack(level, grade) when level < 58, do: round_value(round_value(0.5502 * level + 0.1806) * map_correction(grade))
  defp magical_attack(level, grade) do
    adjusted_level = if rem(level, 2) == 1, do: level - 1, else: level
    round_value((0.2751 * adjusted_level + 16.136) * map_correction(grade))
  end

  defp resistance(:magical, 12, level, grade), do: round_value(max(((level - 12) + 4.5) / 1.5 * acc_correction(grade), 0))
  defp resistance(:magical, 20, level, grade), do: round_value(max(((level - 12) * 1.5 + 4) / 1.5 * acc_correction(grade), 0))
  defp resistance(:physical, 18, level, grade), do: round_value(max((level - 12) / 1.5 * acc_correction(grade) + 3, 0))
  defp resistance(:physical, 19, level, grade), do: round_value(max((level - 12) * acc_correction(grade) + 3, 0))
  defp resistance(_, type, _level, grade) when type in [40, 41], do: %{1 => 2, 2 => 4, 3 => 7, 4 => 9, 5 => 12, 6 => 12}[grade] || 0
  defp resistance(_, _, _, _), do: 0
  defp map_correction(grade), do: %{1 => 0.925, 2 => 1.0175, 3 => 1.11, 4 => 1.2025, 5 => 1.2825, 6 => 1.2825}[grade] || 1
  defp acc_correction(grade), do: %{1 => 0.5, 2 => 0.6, 3 => 0.7, 4 => 0.85, 5 => 1.0, 6 => 1.0}[grade] || 0

  defp primary(stat, item_type, job, level, p7) do
    jobs = %{
      strength: [10, 20, 90],
      dexterity: [50, 60, 100],
      intelligence: [30, 40, 110],
      luck: [70, 80]
    }

    valid = job in Map.fetch!(jobs, stat) or (job == 100 and stat == :intelligence and p7 == 1)
    value = if valid, do: primary_value(item_type, level, 3), else: if(job == 0, do: primary_value(item_type, level, 6), else: 0)
    round_value(value)
  end

  defp primary_value(22, level, divisor), do: 1.8 * level_value(level) / divisor
  defp primary_value(_type, level, divisor), do: level_value(level) / divisor
  defp level_value(level) when level < 51, do: level - 20
  defp level_value(level), do: 2 * level - 90

  defp critical_rate(type, grade) when type > 29 and type < 40, do: %{1 => 6, 2 => 7, 3 => 8, 4 => 9, 5 => 10, 6 => 10}[grade] || 0
  defp critical_rate(type, grade) when type > 39 and type < 60, do: %{1 => 12, 2 => 14, 3 => 16, 4 => 18, 5 => 20, 6 => 20}[grade] || 0
  defp critical_rate(_, _), do: 0

  defp round_value(value), do: value |> Float.round() |> trunc()
end
