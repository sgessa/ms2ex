defmodule Ms2ex.ProtoMetadata.CoordF do
  @moduledoc false
  use Protobuf, syntax: :proto3

  field :x, 1, type: :float
  field :y, 2, type: :float
  field :z, 3, type: :float
end
