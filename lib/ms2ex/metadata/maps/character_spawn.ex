defmodule Ms2ex.Metadata.CharacterSpawn do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct [:coord, :rotation]

  field :coord, 1, type: Ms2ex.Metadata.Coord
  field :rotation, 2, type: Ms2ex.Metadata.Coord
end
