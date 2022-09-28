defmodule Ms2ex.Metadata.Items.RangeOptionType do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field :accessory, 0
  field :armor, 1
  field :pet, 2
  field :weapon, 3
end
