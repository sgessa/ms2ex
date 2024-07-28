defmodule Ms2ex.ProtoMetadata.Items.StatAttributeType do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field :rate, 0
  field :flat, 1
end
