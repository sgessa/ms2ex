defmodule Ms2ex.Metadata.Items.RandomOptionId do
  @moduledoc false
  use Protobuf, syntax: :proto3

  alias Ms2ex.Metadata.Items

  field :id, 1, type: :int32
  field :options, 2, repeated: true, type: Items.RandomOptions
end
