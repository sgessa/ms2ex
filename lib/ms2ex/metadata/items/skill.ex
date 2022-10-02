defmodule Ms2ex.Metadata.Items.Skill do
  @moduledoc false
  use Protobuf, syntax: :proto3

  field :id, 1, type: :int32
  field :level, 1, type: :int32
end
