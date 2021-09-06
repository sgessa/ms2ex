defmodule Ms2ex.Taxi do
  def calc_taxi_cost(map_count, char_level) do
    map_count = if map_count > 1, do: map_count - 1, else: 1

    if char_level <= 24 do
      0.35307 * :math.pow(char_level, 2) + -1.4401 * char_level + 34.075
    else
      char_level = char_level - 24
      0.23451 * :math.pow(char_level, 2) + 24.221 * char_level + 265.66
    end
    |> Kernel.*(map_count)
    |> Kernel./(2)
    |> Kernel.+(0.5)
    |> :math.floor()
    |> trunc()
    |> Kernel.*(-1)
  end

  def calc_rotor_cost(char_level) do
    level = char_level - 10
    level = if level > 0, do: level, else: 0
    30_000 + level * 500
  end
end
