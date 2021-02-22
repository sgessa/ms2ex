defmodule Ms2ex.Metadata.MapInteractable do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct [:id, :name]

  field :id, 1, type: :string
  field :name, 1, type: :string
end
