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

    item_stats = roll_stats(options, item.id)
    selected_stats = Enum.take_random(item_stats, number_of_slots)

    Enum.into(selected_stats, %{}, &{&1.item_attribute, &1})
  end

  # TODO
  defp roll_stats(_options, _item_id) do
    []
  end
end
