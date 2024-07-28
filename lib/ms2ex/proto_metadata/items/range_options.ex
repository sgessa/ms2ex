defmodule Ms2ex.ProtoMetadata.Items.RangeOptions.Stats do
  @moduledoc false
  use Protobuf, map: true, syntax: :proto3

  alias Ms2ex.ProtoMetadata.Items

  field :key, 1, enum: true, type: Items.StatAttribute
  field :value, 2, repeated: true, type: Items.Stat
end

defmodule Ms2ex.ProtoMetadata.Items.RangeOptions do
  @moduledoc false
  use Protobuf, syntax: :proto3

  alias Ms2ex.ProtoMetadata.Items

  field :type, 1, enum: true, type: Items.RangeOptionType
  field :stats, 2, repeated: true, type: Items.RangeOptions.Stats
  field :special_stats, 3, repeated: true, type: Items.RangeOptions.Stats

  def transform_module(), do: Items.RangeOptions.Transform
end

defmodule Ms2ex.ProtoMetadata.Items.RangeOptions.Transform do
  @behaviour Protobuf.TransformModule

  alias Ms2ex.ProtoMetadata.Items

  @impl true
  def encode(data, _module), do: data

  @impl true
  def decode(%Items.RangeOptions{} = options, Items.RangeOptions) do
    stats = Enum.into(options.stats, %{}, &{&1.key, &1.value})
    special_stats = Enum.into(options.special_stats, %{}, &{&1.key, &1.value})

    %Items.RangeOptions{
      type: options.type,
      stats: stats,
      special_stats: special_stats
    }
  end
end
