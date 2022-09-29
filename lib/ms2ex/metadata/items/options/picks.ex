defmodule Ms2ex.Metadata.Items.Options.Pick do
  use Protobuf, syntax: :proto3

  field :id, 1, type: :int32
  field :stats, 2, repeated: true, type: Ms2ex.Metadata.Items.Options.PickStat
end
