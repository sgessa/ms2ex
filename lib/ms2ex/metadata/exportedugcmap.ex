defmodule Ms2ex.Metadata.Exportedugcmap do
  defstruct [:id, :base_cube_position, :indoor_size, :cubes]

  def ids(), do: [:id]
end