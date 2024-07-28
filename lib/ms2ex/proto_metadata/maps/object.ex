defmodule Ms2ex.ProtoMetadata.MapObject do
  @moduledoc false
  use Protobuf, syntax: :proto3

  field :coord, 1, type: Ms2ex.ProtoMetadata.Coord
  field :weapon_id, 2, type: :int32
end
