defmodule Ms2ex.Items.ConstantStats do
  alias Ms2ex.{Item, Items, Storage}

  def get(%Item{} = item, option_id, level_factor) do
    constant_id = item.metadata.options.constant_id
    options = Storage.Items.ConstantOptions.lookup(constant_id, item.rarity)

    if options do
      get_stats(item, options, option_id, level_factor)
    else
      get_default(item, %{}, option_id, level_factor)
    end
  end

  defp get_stats(item, options, option_id, level_factor) do
    %{stats: stats, special_stats: special_stats} = options

    constant_stats = Enum.into(stats, %{}, &{&1.attribute, Items.Stat.build(&1)})

    constant_stats =
      Enum.into(special_stats, constant_stats, &{&1.attribute, Items.Stat.build(&1)})

    # TODO Implement Hidden ndd (defense) and wapmax (Max Weapon Attack)

    if level_factor > 50 do
      get_default(item, constant_stats, option_id, level_factor)
    else
      constant_stats
    end
  end

  # TODO get from script
  defp get_default(_item, constant_stats, _option_id, _level_factor) do
    constant_stats
  end
end
