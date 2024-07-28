defmodule Ms2ex.ProtoMetadata.Items.Options.PickStat do
  use Protobuf, syntax: :proto3

  field :rarity, 1, type: :int32
  field :constants, 2, repeated: true, type: Ms2ex.ProtoMetadata.Items.Options.ConstantPick
  field :static_values, 3, repeated: true, type: Ms2ex.ProtoMetadata.Items.Options.StaticPick
  field :static_rates, 4, repeated: true, type: Ms2ex.ProtoMetadata.Items.Options.StaticPick
end
