defmodule Ms2ex.ProtoMetadata.Items.ConstantOptionId do
  @moduledoc false
  use Protobuf, syntax: :proto3

  alias Ms2ex.ProtoMetadata.Items

  field :id, 1, type: :int32
  field :options, 2, repeated: true, type: Items.ConstantOptions
end
