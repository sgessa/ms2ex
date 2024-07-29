defmodule Ms2ex.Metadata.Item do
  defstruct [:id, :name, :slot_names, :mesh, :default_hairs, :life, :property, :customize, :limit, :skill, :function, :additional_effects, :option, :music, :housing]

  def ids(), do: [:id]
end
