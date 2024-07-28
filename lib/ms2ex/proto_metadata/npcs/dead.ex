defmodule Ms2ex.ProtoMetadata.NpcDead do
  @moduledoc false
  use Protobuf, syntax: :proto3

  field :time, 1, type: :float
  field :actions, 2, repeated: true, type: :string
end
