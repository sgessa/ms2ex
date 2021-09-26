defmodule Ms2ex.Metadata.CoordF do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct x: 0, y: 0, z: 0

  field :x, 1, type: :float
  field :y, 2, type: :float
  field :z, 3, type: :float
end
