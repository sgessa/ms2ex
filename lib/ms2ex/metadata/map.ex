defmodule Ms2ex.Metadata.Map do
  defstruct [:id, :name, :x_block, :property, :limit, :drop, :spawns, :cash_call, :entrance_buffs]

  def ids(), do: [:id]
end
