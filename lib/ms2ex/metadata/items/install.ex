defmodule Ms2ex.Metadata.Items.Install do
  @moduledoc false
  use Protobuf, syntax: :proto3

  field :is_cube_solid, 1, type: :bool
  field :object_id, 2, type: :bool
end
