defmodule Ms2ex.Metadata.Items.Gem do
  @moduledoc false
  use Protobuf, syntax: :proto3

  field :gem, 1, enum: true, type: Ms2ex.Metadata.Items.GemSlot
end
