defmodule Ms2ex.Formulas.ItemRates do
  def static_perfect_guard(base, factor) do
    minimum = Float.round(0.0016 * factor + 0.0624, 3)
    maximum = minimum + 0.013

    if base == 0 do
      {minimum, maximum}
    else
      value = Float.round(maximum * base / 100, 3)
      {value, value}
    end
  end
end
