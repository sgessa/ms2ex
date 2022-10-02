defmodule Ms2ex.Metadata.Items.Gender do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field :male, 0
  field :female, 1
  field :neutral, 2
end
