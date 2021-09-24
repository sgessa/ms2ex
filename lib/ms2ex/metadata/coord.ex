defmodule Ms2ex.Metadata.Coord do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct x: 0, y: 0, z: 0

  field :x, 1, type: :int32
  field :y, 2, type: :int32
  field :z, 3, type: :int32
end
