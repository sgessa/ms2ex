defmodule Ms2ex.Metadata.ServerTable do
  defstruct [:name, :table]

  def ids(), do: [:name]
end
