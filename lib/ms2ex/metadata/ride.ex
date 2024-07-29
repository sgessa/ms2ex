defmodule Ms2ex.Metadata.Ride do
  defstruct [:id, :model, :basic, :speed, :stats]

  def ids(), do: [:id]
end
