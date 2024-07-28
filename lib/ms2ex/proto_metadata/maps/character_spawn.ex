defmodule Ms2ex.ProtoMetadata.CharacterSpawn do
  @moduledoc false
  use Protobuf, syntax: :proto3

  field :coord, 1, type: Ms2ex.ProtoMetadata.Coord
  field :rotation, 2, type: Ms2ex.ProtoMetadata.Coord
end
