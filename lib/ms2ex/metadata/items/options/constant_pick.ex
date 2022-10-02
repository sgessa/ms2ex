defmodule Ms2ex.Metadata.Items.Options.ConstantPick do
  use Protobuf, syntax: :proto3

  field :stat, 1, enum: true, type: Ms2ex.Metadata.Items.StatAttribute
  field :deviation_value, 2, type: :int32
end
