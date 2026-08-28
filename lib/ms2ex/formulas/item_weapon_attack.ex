defmodule Ms2ex.Formulas.ItemWeaponAttack do
  @upgrade_factor 0.06

  @add_wap_tables %{
    50 => %{4 => 0.9828, 5 => 1.4215, 6 => 1.7975},
    60 => %{4 => 2.0159, 5 => 2.2145, 6 => 2.4356},
    70 => %{4 => 3.1675, 5 => 3.0833, 6 => 3.1261},
    80 => %{4 => 4.76, 5 => 4.2835, 6 => 4.0804},
    90 => %{4 => 6.9602, 5 => 5.9416, 6 => 5.399}
  }

  @slot_coefficients %{
    30 => 1.0,
    31 => 1.03,
    32 => 0.95,
    33 => 0.92,
    34 => 0.95,
    50 => 1.1,
    51 => 1.03,
    52 => 1.2,
    53 => 1.05,
    54 => 1.0,
    55 => 1.13,
    56 => 0.96
  }
  @speed_coefficients %{
    30 => 0.95,
    31 => 1.05,
    32 => 1.0,
    33 => 1.1,
    34 => 1.0,
    50 => 0.95,
    51 => 1.05,
    52 => 1.0,
    53 => 0.9,
    54 => 1.0,
    55 => 1.05,
    56 => 0.95
  }
  @deviations %{
    1 => %{
      30 => 0.05,
      31 => 0.15,
      32 => 0.02,
      33 => 0.05,
      34 => 0.15,
      50 => 0.1,
      51 => 0.05,
      52 => 0.05,
      53 => 0.1,
      54 => 0.0,
      55 => 0.05,
      56 => 0.1
    },
    2 => %{
      30 => 0.1,
      31 => 0.3,
      32 => 0.04,
      33 => 0.1,
      34 => 0.3,
      50 => 0.2,
      51 => 0.1,
      52 => 0.1,
      53 => 0.2,
      54 => 0.0,
      55 => 0.1,
      56 => 0.2
    }
  }
  @grade_coefficients %{
    1 => %{1 => 0.9, 2 => 0.98, 3 => 1.06, 4 => 1.14, 5 => 1.21, 6 => 1.4},
    2 => %{1 => 0.9, 2 => 0.98, 3 => 1.06, 4 => 1.14, 5 => 1.21, 6 => 1.4}
  }
  @static_coefficients %{1 => 0.1, 2 => 0.12, 3 => 0.14, 4 => 0.16, 5 => 0.18, 6 => 0.2}

  def constant_value(:min, base, deviation, type, _job, factor, grade, level),
    do: constant(base, deviation, type, trunc(factor), grade, level, :min)

  def constant_value(:max, base, deviation, type, _job, factor, grade, level),
    do: constant(base, deviation, type, trunc(factor), grade, level, :max)

  def static_value(:max, base, deviation, type, _job, factor, grade, level) do
    factor = trunc(factor)
    level_base = level_base(factor, level)
    effective_type = if type == 54, do: 52, else: type
    slot = rounded(level_base * coefficient(effective_type) / speed(effective_type))
    add = static_add(base, deviation, type, factor, grade, level)

    max_value =
      max(slot * Map.fetch!(@static_coefficients, grade) * (1 + deviation(type, 1)), 2) + add

    min_value = max(max_value * 0.78, 1)

    if base == 0,
      do: {min_value, max_value},
      else: {rounded(max_value * base / 100), rounded(max_value * base / 100)}
  end

  defp constant(base, dev, type, factor, grade, level, bound) do
    slot = rounded(level_base(factor, level) * coefficient(type) / speed(type))
    add = constant_add(base, dev, type, factor, grade, level)
    sign = if bound == :min, do: 1 - deviation(type, dev), else: 1 + deviation(type, dev)
    base_value = rounded(slot * grade_coefficient(dev, grade) * sign)

    if level >= 70 and base > 0,
      do: rounded(base_value * base / 100) + rounded(add * sign * base / 100),
      else: (base_value + add) |> max(0)
  end

  defp constant_add(_base, _dev, _type, _factor, grade, level) when grade < 4 or level <= 49,
    do: 0

  defp constant_add(_base, dev, type, factor, grade, level) do
    local = level_base(factor, level)
    table = @add_wap_tables[band(level)]
    slot = rounded(local * coefficient(type) / speed(type))

    grade_value =
      (rounded(slot * grade_coefficient(dev, grade) * (1 - deviation(type, dev))) +
         rounded(slot * grade_coefficient(dev, grade) * (1 + deviation(type, dev)))) / 2 *
        Map.get(table, grade, 0)

    epic =
      (rounded(slot * grade_coefficient(dev, 4) * (1 - deviation(type, dev))) +
         rounded(slot * grade_coefficient(dev, 4) * (1 + deviation(type, dev)))) / 2 *
        Map.get(table, 4, 0)

    rounded(grade_value + epic * (grade - 4))
  end

  defp static_add(_base, _dev, _type, _factor, grade, level) when grade < 4 or level <= 49, do: 0

  defp static_add(_base, _dev, type, factor, grade, level) do
    effective_type = if type == 54, do: 52, else: type

    slot =
      rounded(level_base(factor, level) * coefficient(effective_type) / speed(effective_type))

    max(slot * Map.fetch!(@static_coefficients, grade) * (1 + deviation(type, 1)), 2) |> rounded()
  end

  defp level_base(1, _level), do: 5

  defp level_base(factor, level) do
    Enum.reduce(2..factor, 5, fn index, local ->
      local +
        if(index > 49 and level >= 60,
          do: local * @upgrade_factor,
          else: max(index / 30 * 20 - 0.8, 0)
        )
    end)
  end

  defp band(level) when level < 60, do: 50
  defp band(level) when level < 70, do: 60
  defp band(level) when level < 80, do: 70
  defp band(level) when level < 90, do: 80
  defp band(_), do: 90
  defp coefficient(type), do: Map.get(@slot_coefficients, type, 1.0)
  defp speed(type), do: Map.get(@speed_coefficients, type, 1.0)
  defp deviation(type, dev), do: get_in(@deviations, [dev, type]) || 0.0
  defp grade_coefficient(dev, grade), do: get_in(@grade_coefficients, [dev, grade]) || 1.0
  defp rounded(value), do: value |> Float.round() |> trunc()
end
