defmodule Ms2ex.Items.RandomStats do
  alias Ms2ex.{Item, Items, Storage}

  def get(%Item{} = item) do
    random_id = item.metadata.option.random_id
    options = Storage.Items.RandomOptions.lookup(random_id, item.rarity)

    get_stats(item, options)
  end

  defp get_stats(_item, nil), do: %{}

  defp get_stats(item, options) do
    [min_slots, max_slots] = options.slots
    number_of_slots = Enum.random(min_slots..max_slots)

    item_stats = roll_stats(options, item)
    selected_stats = Enum.take_random(item_stats, number_of_slots)

    Enum.into(selected_stats, %{}, &{&1.item_attribute, &1})
  end

  defp roll_stats(options, item) do
    {ranges, special_ranges} = get_ranges(item)

    item_stats =
      Enum.reduce(options.stats, [], fn stat, acc ->
        if Map.has_key?(ranges, stat.attribute) do
          acc ++ [build_item_stat(item, stat, ranges, options)]
        else
          acc
        end
      end)

    Enum.reduce(options.special_stats, item_stats, fn stat, acc ->
      if Map.has_key?(special_ranges, stat.attribute) do
        acc ++ [build_item_stat(item, stat, ranges, options)]
      else
        acc
      end
    end)
  end

  defp get_ranges(item) do
    cond do
      Items.accessory?(item) -> Storage.Items.RangeOptions.ranges(:accessory)
      Items.armor?(item) -> Storage.Items.RangeOptions.ranges(:armor)
      Items.weapon?(item) -> Storage.Items.RangeOptions.ranges(:weapon)
      true -> Storage.Items.RangeOptions.ranges(:pet)
    end
  end

  defp build_item_stat(item, stat, ranges, options) do
    idx = roll(item)
    r = ranges[stat.attribute][idx]

    item_stat = Items.Stat.build(r)

    if options.multiply_factor > 0 do
      flat = item_stat.flat * trunc(Float.ceil(options.multiply_factor))
      rate = item_stat.rate * options.multiply_factor

      Map.merge(item_stat, %{flat: flat, rate: rate})
    else
      item_stat
    end
  end

  # Returns index 0~7 for equip level 70-
  # Returns index 8~15 for equip level 70+
  defp roll(item) do
    level_factor = item.metadata.option.level_factor
    random = :rand.uniform()

    if level_factor >= 70 do
      case random do
        n when n >= 0.0 and n < 0.24 -> 8
        n when n >= 0.24 and n < 0.48 -> 9
        n when n >= 0.48 and n < 0.74 -> 10
        n when n >= 0.74 and n < 0.9 -> 11
        n when n >= 0.9 and n < 0.966 -> 12
        n when n >= 0.966 and n < 0.985 -> 13
        n when n >= 0.985 and n < 0.9975 -> 14
      end
    else
      case random do
        n when n >= 0.0 and n < 0.24 -> 0
        n when n >= 0.24 and n < 0.48 -> 1
        n when n >= 0.48 and n < 0.74 -> 2
        n when n >= 0.74 and n < 0.9 -> 3
        n when n >= 0.9 and n < 0.966 -> 4
        n when n >= 0.966 and n < 0.985 -> 5
        n when n >= 0.985 and n < 0.9975 -> 6
        _ -> 7
      end
    end
  end
end
