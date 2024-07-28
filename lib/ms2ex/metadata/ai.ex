defmodule Ms2ex.Metadata.Ai do
  defstruct [:name, :reserved, :battle, :battle_end, :ai_presets]

  def id(), do: :name
end
