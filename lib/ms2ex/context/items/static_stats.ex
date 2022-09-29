defmodule Ms2ex.Items.StaticStats do
  alias Ms2ex.{Item, Items, Storage}

  def get(_item, _option_id, level_factor) when level_factor < 50 do
    %{}
  end

  def get(%Item{} = item, option_id, level_factor) do
    static_id = item.metadata.options.static_id
    options = Storage.Items.StaticOptions.lookup(static_id, item.rarity)

    if options do
      get_stats(item, options, option_id, level_factor)
    else
      get_default(item, %{}, option_id, level_factor)
    end
  end

  defp get_stats(item, options, option_id, level_factor) do
    %{stats: stats, special_stats: special_stats} = options

    static_stats = Enum.into(stats, %{}, &{&1.attribute, Items.Stat.build(&1)})
    static_stats = Enum.into(special_stats, static_stats, &{&1.attribute, Items.Stat.build(&1)})

    # TODO: Implement Hidden ndd (defense) and wapmax (Max Weapon Attack)

    get_default(item, static_stats, option_id, level_factor)
  end

  # TODO get from script
  defp get_default(_item, static_stats, _option_id, _level_factor) do
    static_stats
  end
end
