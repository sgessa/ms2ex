defmodule Ms2ex.Metadata.MapPortal do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct [
    :id,
    :name,
    :enabled?,
    :visible?,
    :mini_map_visible?,
    :target,
    :coord,
    :rotation,
    :target_portal_id,
    :portal_type,
    :trigger_id
  ]

  field :id, 1, type: :int32
  field :name, 2, type: :string
  field :enabled?, 3, type: :bool
  field :visible?, 4, type: :bool
  field :mini_map_visible?, 5, type: :bool
  field :target, 6, type: :int32
  field :coord, 7, type: Ms2ex.Metadata.Coord
  field :rotation, 8, type: Ms2ex.Metadata.Coord
  field :target_portal_id, 9, type: :int32
  field :portal_type, 10, type: :int32
  field :trigger_id, 11, type: :int32
end
