defmodule Ms2ex.Metadata.MapEntity do
  defstruct [:x_block, :guid, :name, :block]

  def ids(), do: [:x_block, :guid]
end
