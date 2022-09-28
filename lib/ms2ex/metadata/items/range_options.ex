defmodule Ms2ex.Metadata.Items.RangeOptions.Stats do
  @moduledoc false
  use Protobuf, map: true, syntax: :proto3

  alias Ms2ex.Metadata.Items

  field :key, 1, enum: true, type: Items.StatAttribute
  field :value, 2, repeated: true, type: Items.Stat
end

defmodule Ms2ex.Metadata.Items.RangeOptions do
  @moduledoc false
  use Protobuf, syntax: :proto3

  alias Ms2ex.Metadata.Items

  field :type, 1, enum: true, type: Items.RangeOptionType
  field :stats, 2, repeated: true, type: Items.RangeOptions.Stats
  field :special_stats, 3, repeated: true, type: Items.RangeOptions.Stats
end
