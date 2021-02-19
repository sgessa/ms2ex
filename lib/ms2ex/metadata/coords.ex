defmodule Ms2ex.Metadata.Coord do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct x: 0, y: 0, z: 0

  field :x, 1, type: :int32
  field :y, 2, type: :int32
  field :z, 3, type: :int32

  @block_size 150
  def closest_block(%__MODULE__{x: x, y: y, z: z}) do
    x = (x + 75) / @block_size * @block_size
    y = (y + 75) / @block_size * @block_size
    z = (z + 75) / @block_size * @block_size
    %__MODULE__{x: x, y: y, z: z}
  end

  def length(%__MODULE__{x: x, y: y, z: z}) do
    :math.sqrt(x * x + y * y + z * z)
  end

  def subtract(%__MODULE__{} = left, %__MODULE__{} = right) do
    %__MODULE__{x: left.x - right.x, y: left.y - right.y, z: left.z - right.z}
  end

  def to_float(%{x: x, y: y, z: z}) do
    __MODULE__.new(x: x + 0.0, y: y + 0.0, z: z + 0.0)
  end
end
