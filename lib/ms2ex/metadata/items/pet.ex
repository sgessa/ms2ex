defmodule Ms2ex.Metadata.Items.Pet do
  @moduledoc false
  use Protobuf, syntax: :proto3

  field :pet_id, 0, type: :int32
end
