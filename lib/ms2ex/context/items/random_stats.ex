defmodule Ms2ex.Items.RandomStats do
  alias Ms2ex.{Item, Items, Enums}
  alias Ms2ex.Storage

  def get(%Item{} = item) do
    random_id = item.metadata.option.random_id
    options = Storage.Tables.ItemOptions.find_random(random_id, item.rarity)

    get_stats(item, options)
  end

  defp get_stats(_item, nil), do: %{}

  defp get_stats(_item, random_options) do
    %{num_pick: picks, entries: entries} = random_options

    pick_count = Enum.random(picks.min..picks.max)

    Enum.map(entries, &process_stat(&1))
    |> Enum.take_random(pick_count)
    |> Enum.map(&{&1.attribute, &1})
    |> Map.new()
  end

  defp process_stat(%{values: values, basic_attribute: attr}) do
    value = Enum.random(values.min..values.max)
    Items.Stat.build(Enums.BasicStatType.get_key(attr), :basic, value, :flat)
  end

  defp process_stat(%{rates: values, basic_attribute: attr}) do
    value = :rand.uniform() * (values.max - values.min) + values.max
    Items.Stat.build(Enums.BasicStatType.get_key(attr), :basic, value, :rate)
  end

  defp process_stat(%{values: values, special_attribute: attr}) do
    value = Enum.random(values.min..values.max)
    Items.Stat.build(Enums.SpecialStatType.get_key(attr), :special, value, :flat)
  end

  defp process_stat(%{rates: values, special_attribute: attr}) do
    value = :rand.uniform() * (values.max - values.min) + values.max
    Items.Stat.build(Enums.SpecialStatType.get_key(attr), :special, value, :rate)
  end
end
