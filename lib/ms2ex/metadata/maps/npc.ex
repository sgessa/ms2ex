defmodule Ms2ex.Metadata.MapNpc do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct [
    :id,
    :model,
    :instance,
    :position,
    :rotation,
    :patrol_data_uuid,
    :spawn_on_field?,
    :day_die?,
    :night_die?
  ]

  field :id, 1, type: :int32
  field :model, 2, type: :string
  field :instance, 3, type: :string
  field :position, 4, type: Ms2ex.Metadata.Coord
  field :rotation, 5, type: Ms2ex.Metadata.Coord
  field :patrol_data_uuid, 6, type: :string
  field :spawn_on_field?, 7, type: :bool
  field :day_die?, 8, type: :bool
  field :night_die?, 9, type: :bool
end
