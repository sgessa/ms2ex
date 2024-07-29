defmodule Ms2ex.Metadata.Table do
  defstruct [:name, :table]

  def ids(), do: [:name]
end
