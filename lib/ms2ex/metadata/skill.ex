defmodule Ms2ex.Metadata.Skill do
  defstruct [:id, :name, :property, :state, :levels]

  def ids(), do: [:id]
end
