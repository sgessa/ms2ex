defmodule Ms2ex.Metadata.ServerTable do
  defstruct [:name, :table]

  def id(), do: :name
end
