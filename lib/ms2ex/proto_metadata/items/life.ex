defmodule Ms2ex.ProtoMetadata.Items.Life do
  @moduledoc false
  use Protobuf, syntax: :proto3

  field :duration_period, 1, type: :int32
  field :expiration_time, 2, type: Google.Protobuf.Timestamp
  field :expiration_type, 3, enum: true, type: Ms2ex.ProtoMetadata.Items.ExpirationType
  field :expiration_type_duration, 4, type: :int32
end
