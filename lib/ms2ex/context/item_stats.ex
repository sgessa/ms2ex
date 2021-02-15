defmodule Ms2ex.ItemStats do
  def set_basic_attributes(metadata, rarity) do
    basic_attributes = Enum.find(metadata.basic, &(&1.rarity == rarity))

    if basic_attributes do
      find_options(basic_attributes.stats)
    end
  end

  def set_bonus_attributes(metadata, rarity) do
    bonus_attributes = Enum.find(metadata.random_bonus, &(&1.rarity == rarity and &1.slots > 0))

    if bonus_attributes do
      stats = get_random_options(bonus_attributes.slots, bonus_attributes.stats)
      find_options(stats)
    end
  end

  # TODO randomize value
  defp find_options(stats) do
    Enum.reduce(stats, [], fn stat, attributes ->
      if stat.value != 0 do
        attributes ++ [%{type: stat.type, value: stat.value, percentage: 0}]
      else
        attributes ++ [%{type: stat.type, value: 0, percentage: stat.percentage}]
      end
    end)
  end

  defp get_random_options(slots, stats) when slots > length(stats), do: stats
  defp get_random_options(slots, stats), do: Enum.take_random(stats, slots)
end
