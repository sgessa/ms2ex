defmodule Ms2ex.Metadata.AdditionalEffect do
  defstruct [:id, :level, :condition, :property, :consume, :reflect, :update, :status, :recovery, :dot, :shield, :invoke_effect, :skills]

  def id(), do: :id
end
