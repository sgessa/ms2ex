defmodule Ms2ex.Metadata.Coord do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct x: 0, y: 0, z: 0

  field :x, 1, type: :int32
  field :y, 2, type: :int32
  field :z, 3, type: :int32

  def closest_block(%__MODULE__{x: x, y: y, z: z}) do
    x = (x + 75) / 150 * 150
    y = (y + 75) / 150 * 150
    z = (z + 75) / 150 * 150
    %__MODULE__{x: x, y: y, z: z}
  end

  def length(%__MODULE__{x: x, y: y, z: z}) do
    :math.sqrt(x * x + y * y + z * z)
  end

  def subtract(%__MODULE__{} = left, %__MODULE__{} = right) do
    %__MODULE__{x: left.x - right.x, y: left.y - right.y, z: left.z - right.z}
  end
end
