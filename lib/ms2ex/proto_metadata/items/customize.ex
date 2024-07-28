defmodule Ms2ex.ProtoMetadata.Items.Customize do
  @moduledoc false
  use Protobuf, syntax: :proto3

  field :color_palette, 1, type: :int32
  field :color_index, 2, type: :int32
  field :hair_presets, 3, repeated: true, type: Ms2ex.ProtoMetadata.Items.Hair
end
