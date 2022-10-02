defmodule Ms2ex.Metadata.Items.Hair do
  @moduledoc false
  use Protobuf, syntax: :proto3

  field :back_position_coord, 1, type: Ms2ex.Metadata.CoordF
  field :back_position_rotation, 2, type: Ms2ex.Metadata.CoordF
  field :front_position_coord, 3, type: Ms2ex.Metadata.CoordF
  field :front_position_rotation, 4, type: Ms2ex.Metadata.CoordF
  field :min_scale, 5, type: :float
  field :max_scale, 6, type: :float
end
