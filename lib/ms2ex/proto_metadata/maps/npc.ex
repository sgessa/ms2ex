defmodule Ms2ex.ProtoMetadata.MapNpc do
  @moduledoc false
  use Protobuf, syntax: :proto3

  field :id, 1, type: :int32
  field :model, 2, type: :string
  field :instance, 3, type: :string
  field :position, 4, type: Ms2ex.ProtoMetadata.Coord
  field :rotation, 5, type: Ms2ex.ProtoMetadata.Coord
  field :patrol_data_uuid, 6, type: :string
  field :spawn_on_field?, 7, type: :bool
  field :day_die?, 8, type: :bool
  field :night_die?, 9, type: :bool
end
