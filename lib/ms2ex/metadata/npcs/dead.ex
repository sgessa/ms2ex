defmodule Ms2ex.Metadata.NpcDead do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct [:time, actions: []]

  field :time, 1, type: :float
  field :actions, 2, repeated: true, type: :string
end
