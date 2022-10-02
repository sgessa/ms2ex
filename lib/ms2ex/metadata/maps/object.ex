defmodule Ms2ex.Metadata.MapObject do
  @moduledoc false
  use Protobuf, syntax: :proto3

  field :coord, 1, type: Ms2ex.Metadata.Coord
  field :weapon_id, 2, type: :int32
end
