defmodule Ms2ex.Metadata.MapInteractable do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct [:uuid, :name]

  field :uuid, 1, type: :string
  field :name, 1, type: :string
end
