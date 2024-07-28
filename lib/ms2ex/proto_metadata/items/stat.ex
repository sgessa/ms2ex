defmodule Ms2ex.ProtoMetadata.Items.Stat do
  @moduledoc false
  use Protobuf, syntax: :proto3

  field :attribute, 1, enum: true, type: Ms2ex.ProtoMetadata.Items.StatAttribute
  field :value, 2, type: :float
  field :type, 3, enum: true, type: Ms2ex.ProtoMetadata.Items.StatAttributeType
end
