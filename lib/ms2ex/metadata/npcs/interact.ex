defmodule Ms2ex.Metadata.NpcInteract do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct [
    :function,
    :casting_time,
    :cool_down_time
  ]

  field :function, 1, type: :string
  field :casting_time, 2, type: :int32
  field :cool_down_time, 3, type: :int32
end
