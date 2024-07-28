defmodule Ms2ex.ProtoMetadata.Coord do
  @moduledoc false
  use Protobuf, syntax: :proto3

  field :x, 1, type: :int32
  field :y, 2, type: :int32
  field :z, 3, type: :int32
end
