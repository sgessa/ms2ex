defmodule Ms2ex.ProtoMetadata.Items.Options do
  @moduledoc false
  use Protobuf, syntax: :proto3

  field :static_id, 1, type: :int32
  field :random_id, 2, type: :int32
  field :constant_id, 3, type: :int32
  field :level_factor, 4, type: :float
  field :id, 5, type: :int32
end
