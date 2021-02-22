defmodule Ms2ex.Metadata.NpcDistance do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct [
    :avoid,
    :sight,
    :sight_height_up,
    :sight_height_down,
    :last_sight_radius,
    :last_sight_up,
    :last_sight_down
  ]

  field :avoid, 1, type: :int32
  field :sight, 2, type: :int32
  field :sight_height_up, 3, type: :int32
  field :sight_height_down, 4, type: :int32
  field :last_sight_radius, 5, type: :int32
  field :last_sight_up, 6, type: :int32
  field :last_sight_down, 7, type: :int32
end
