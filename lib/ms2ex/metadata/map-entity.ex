defmodule Ms2ex.Metadata.MapEntity do
  defstruct [:x_block, :guid, :name, :block]

  def id(), do: :x_block
end
