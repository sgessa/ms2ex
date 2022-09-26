defmodule Ms2ex.Metadata.Items.ExpirationType do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field :none, 0
  field :weeks, 1
  field :months, 2
end
