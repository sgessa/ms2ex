defmodule Ms2ex.Formulas.ItemDefense do
  @upgrade 0.06
  @slot %{13 => 0.21, 14 => 0.32, 15 => 0.3, 16 => 0.06, 17 => 0.06, 18 => 0.05, 19 => 0.05, 20 => 0.05, 21 => 0.05, 22 => 0.62, 41 => 0.15}
  @job %{0 => 0.8, 1 => 0.9, 10 => 1.1, 20 => 1.0, 30 => 0.9, 40 => 0.88, 50 => 0.93, 60 => 0.95, 70 => 0.95, 80 => 0.9, 90 => 0.97, 100 => 1.0, 110 => 0.9}
  @grade %{1 => %{1 => 0.9, 2 => 0.98, 3 => 1.06, 4 => 1.14, 5 => 1.21, 6 => 1.4}, 2 => %{1 => 1.0, 2 => 1.1, 3 => 1.2, 4 => 1.3, 5 => 1.45, 6 => 1.6}}
  @add %{50 => %{4 => 0.9846, 5 => 1.426, 6 => 1.795}, 60 => %{4 => 2.016, 5 => 2.22, 6 => 2.442}, 70 => %{4 => 3.174, 5 => 3.084, 6 => 3.129}, 80 => %{4 => 4.7672, 5 => 4.2895, 6 => 4.0858}, 90 => %{4 => 6.9675, 5 => 5.947, 6 => 5.4043}}
  @static_armor %{1 => 0.1, 2 => 0.12, 3 => 0.14, 4 => 0.16, 5 => 0.18, 6 => 0.2}
  @static_accessory %{1 => 0.4, 2 => 0.55, 3 => 0.7, 4 => 0.85, 5 => 1.0, 6 => 1.0}

  def constant(base, deviation, type, job, factor, grade, level) do
    factor = trunc(factor)
    local = armor_level(factor)
    slot = Map.get(@slot, type, 0)
    job_value = Map.get(@job, if(type == 21, do: 0, else: job), 0.8)
    grade_value = get_in(@grade, [deviation, grade]) || 0
    add = add_value(local, slot, job_value, deviation, grade, level)
    result = round_value(local * slot * job_value * grade_value) + add
    if level >= 70 and base > 0 and type != 21, do: round_value((result - add) * base / 100) + round_value(add * base / 100), else: result
  end

  def static(base, type, job, factor, grade, level) do
    factor = trunc(factor)
    local = armor_level(factor)
    slot = Map.get(@slot, type, 0)
    coefficient = if type in [12, 18, 19, 20], do: Map.get(@static_accessory, grade, 0), else: Map.get(@static_armor, grade, 0)
    job_value = Map.get(@job, if(type == 21, do: 0, else: job), 0.8)
    maximum = max(round_value(local * slot * job_value * coefficient), if(type in [12, 18, 19, 20], do: 0, else: 4))
    minimum = if maximum < 466, do: round_value(maximum * max(0.0598 * :math.log(maximum) + 0.432, 0.5)), else: max(round_value(maximum * 0.8), 1)
    add = static_add(type, factor, grade, level, local, slot, job_value)
    if base == 0, do: {minimum + add, maximum + add}, else: {round_value(maximum * base / 100) + add, round_value(maximum * base / 100) + add}
  end

  defp armor_level(1), do: 9
  defp armor_level(factor), do: Enum.reduce(2..factor, 9, fn index, value -> value + if(index > 49, do: value * @upgrade, else: max(1 + index / 10 * 4, 0)) end)
  defp add_value(_local, _slot, _job, _deviation, grade, level) when grade < 4 or level <= 49, do: 0
  defp add_value(local, slot, job, deviation, grade, level) do
    factor = Map.get(@add, band(level), %{})
    current = round_value(local * slot * job * (get_in(@grade, [deviation, grade]) || 0)) * Map.get(factor, grade, 0)
    epic = round_value(local * slot * job * (get_in(@grade, [deviation, 4]) || 0)) * Map.get(factor, 4, 0)
    round_value(current + epic * (grade - 4))
  end
  defp static_add(_type, _factor, grade, level, _local, _slot, _job) when grade < 4 or level <= 49, do: 0
  defp static_add(type, _factor, grade, level, local, slot, job) do
    table = Map.get(@add, band(level), %{})
    coefficient = if type in [12, 18, 19, 20], do: Map.get(@static_accessory, grade, 0), else: Map.get(@static_armor, grade, 0)
    epic_coefficient = if type in [12, 18, 19, 20], do: Map.get(@static_accessory, 4, 0), else: Map.get(@static_armor, 4, 0)
    grade_add = max(round_value(local * slot * if(type == 21, do: 0.8, else: job) * coefficient), if(type in [12, 18, 19, 20], do: 0, else: 4)) * Map.get(table, grade, 0)
    epic_add = max(round_value(local * slot * if(type == 21, do: 0.8, else: job) * epic_coefficient), if(type in [12, 18, 19, 20], do: 0, else: 4)) * Map.get(table, 4, 0)
    round_value(grade_add + epic_add * (grade - 4))
  end
  defp band(level) when level < 60, do: 50
  defp band(level) when level < 70, do: 60
  defp band(level) when level < 80, do: 70
  defp band(level) when level < 90, do: 80
  defp band(_), do: 90
  defp round_value(value), do: value |> Float.round() |> trunc()
end
