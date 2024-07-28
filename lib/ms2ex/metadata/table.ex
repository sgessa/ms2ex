defmodule Ms2ex.Metadata.Table do
  defstruct [:name, :table]

  def id(), do: :name
end
