defmodule Ms2ex.ProtoMetadata.Items.Options.StaticPick do
  use Protobuf, syntax: :proto3

  field :stat, 1, enum: true, type: Ms2ex.ProtoMetadata.Items.StatAttribute
  field :deviation_value, 2, type: :int32
end
