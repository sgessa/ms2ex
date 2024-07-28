defmodule Ms2ex.ProtoMetadata.InteractableObject do
  @moduledoc false
  use Protobuf, syntax: :proto3

  field :uuid, 1, type: :string
  field :name, 1, type: :string
end
