defmodule Ms2ex.ProtoMetadata.Items.Basic do
  @moduledoc false
  use Protobuf, syntax: :proto3

  field :tag, 1, type: :string
end
