defmodule Ms2ex.ItemStats do
  alias Ms2ex.Inventory.Item
  alias Ms2ex.Metadata

  def load(%Item{} = item) do
    case Metadata.ItemStatList.lookup(item.item_id) do
      {:ok, metadata} ->
        item
        |> load_basic_attributes(metadata.basic_attributes)
        |> load_bonus_attributes(metadata.bonus_attributes)
    end
  end

  defp load_basic_attributes(item, basic_attributes) do
    basic_attributes = Enum.find(basic_attributes, &(&1.rarity == item.rarity))

    if basic_attributes do
      load_options(item, :basic_attributes, basic_attributes.stats)
    else
      item
    end
  end

  defp load_bonus_attributes(item, bonus_attributes) do
    bonus_attributes = Enum.find(bonus_attributes, &(&1.rarity == item.rarity || &1.slots != 0))

    if bonus_attributes do
      stats = get_random_options(bonus_attributes.slots, bonus_attributes.stats)
      load_options(item, :bonus_attributes, stats)
    else
      item
    end
  end

  # TODO randomize value
  defp load_options(item, attr_type, stats) do
    attrs =
      Enum.reduce(stats, [], fn stat, attributes ->
        if stat.value != 0 do
          attributes ++ [%{type: stat.type, value: stat.value, percentage: 0}]
        else
          attributes ++ [%{type: stat.type, value: 0, percentage: stat.percentage}]
        end
      end)

    Map.put(item, attr_type, attrs)
  end

  defp get_random_options(slots, stats) when slots > length(stats), do: stats

  defp get_random_options(slots, stats) do
    Enum.take_random(stats, slots)
  end
end
