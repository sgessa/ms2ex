defmodule Ms2ex.Storage.Items.RangeOptions do
  # TODO: rewrite with redis & delete this

  @moduledoc false
  use Protobuf, syntax: :proto3

  alias Ms2ex.ProtoMetadata.Items

  field :items, 1, repeated: true, type: Items.RangeOptions

  @range_table :item_range_option_metadata
  @special_range_table :item_special_range_option_metadata

  def store() do
    list =
      [:code.priv_dir(:ms2ex), "resources", "ms2-item-option-range-metadata"]
      |> Path.join()
      |> File.read!()
      |> __MODULE__.decode()

    :ets.new(@range_table, [:protected, :set, :named_table])
    :ets.new(@special_range_table, [:protected, :set, :named_table])

    for range_option <- list.items do
      :ets.insert(@range_table, {range_option.type, range_option.stats})
      :ets.insert(@special_range_table, {range_option.type, range_option.special_stats})
    end
  end

  def ranges(type) do
    {
      lookup(@range_table, type),
      lookup(@special_range_table, type)
    }
  end

  defp lookup(table, type) do
    case :ets.lookup(table, type) do
      [{_type, stats}] -> stats
      _ -> nil
    end
  end
end
