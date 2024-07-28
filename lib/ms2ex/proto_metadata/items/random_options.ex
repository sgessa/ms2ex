defmodule Ms2ex.ProtoMetadata.Items.RandomOptions do
  @moduledoc false
  use Protobuf, syntax: :proto3

  alias Ms2ex.ProtoMetadata.Items

  field :rarity, 1, type: :int32
  field :multiply_factor, 2, type: :float
  field :slots, 3, repeated: true, type: :int32
  field :stats, 4, repeated: true, type: Items.Stat
  field :special_stats, 5, repeated: true, type: Items.Stat
end
