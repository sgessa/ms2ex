defmodule Ms2ex.Formulas.ItemStaticStats do
  def value(:physical_atk, base, factor, type), do: attack(base, factor, type)
  def value(:magical_atk, base, factor, type), do: attack(base, factor, type)
  def value(:physical_res, base, factor, _type), do: resistance(base, factor)
  def value(:magical_res, base, factor, type), do: magical_resistance(base, factor, type)
  def value(:health, base, factor, type), do: health(base, factor, type)

  defp attack(base, factor, type) when type > 29 and type < 60 do
    value = -3.8e-6 * :math.pow(factor, 3) + 0.0009 * :math.pow(factor, 2) + 0.0294 * factor
    value = if type > 49, do: value * 1.8, else: value
    minimum = round_value(value)
    finish_range(base, minimum, minimum + 3)
  end

  defp attack(_base, _factor, _type), do: {0, 0}

  defp resistance(base, factor) do
    minimum = round_value(1.0e-5 * :math.pow(factor, 3) - 0.003 * :math.pow(factor, 2) + 0.367 * factor + 4.8841)
    maximum = if minimum < 5, do: minimum + 3, else: if(minimum == 5, do: minimum + 4, else: minimum + 5)
    finish_range(base, minimum, maximum)
  end

  defp magical_resistance(base, factor, 40) do
    minimum = round_value(max(polynomial(factor), 1))
    finish_range(base, minimum, range_maximum(minimum))
  end

  defp magical_resistance(base, factor, _type) do
    minimum = round_value(max(polynomial(factor) * 0.4, 1))
    finish_range(base, minimum, range_maximum(minimum))
  end

  defp health(base, factor, 22) do
    minimum = round_value(max(health_polynomial(factor), 1) * 1.8)
    finish_range(base, minimum, health_maximum(minimum))
  end

  defp health(base, factor, _type) do
    minimum = round_value(max(health_polynomial(factor), 1))
    finish_range(base, minimum, health_maximum(minimum))
  end

  defp polynomial(factor), do: 1.0e-5 * :math.pow(factor, 3) - 0.003 * :math.pow(factor, 2) + 0.367 * factor + 4.8841
  defp health_polynomial(factor), do: -0.00007 * :math.pow(factor, 3) + 0.0162 * :math.pow(factor, 2) + 0.1656 * factor - 0.5098
  defp range_maximum(minimum) when minimum < 5, do: minimum + 3
  defp range_maximum(5), do: 9
  defp range_maximum(minimum), do: minimum + 5
  defp health_maximum(minimum) when minimum < 7, do: minimum + 4
  defp health_maximum(minimum) when minimum < 9, do: minimum + 5
  defp health_maximum(minimum) when minimum < 11, do: minimum + 6
  defp health_maximum(minimum) when minimum < 14, do: minimum + 7
  defp health_maximum(minimum) when minimum < 16, do: minimum + 8
  defp health_maximum(minimum) when minimum < 20, do: minimum + 9
  defp health_maximum(minimum) when minimum < 22, do: minimum + 10
  defp health_maximum(minimum) when minimum < 25, do: minimum + 11
  defp health_maximum(minimum) when minimum < 28, do: minimum + 12
  defp health_maximum(minimum) when minimum < 32, do: minimum + 13
  defp health_maximum(minimum) when minimum < 37, do: minimum + 14
  defp health_maximum(minimum) when minimum < 42, do: minimum + 15
  defp health_maximum(minimum) when minimum < 46, do: minimum + 16
  defp health_maximum(minimum) when minimum < 53, do: minimum + 17
  defp health_maximum(minimum) when minimum < 63, do: minimum + 18
  defp health_maximum(minimum) when minimum < 75, do: minimum + 19
  defp health_maximum(minimum), do: minimum + 20

  defp finish_range(0, minimum, maximum), do: {minimum, maximum}
  defp finish_range(base, _minimum, maximum) do
    value = round_value(maximum * base / 100)
    {value, value}
  end

  defp round_value(value), do: value |> Float.round() |> trunc()
end
