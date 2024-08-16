defmodule Ms2ex.Context.MapBlock do
  alias Ms2ex.Types.Coord

  @block_size 150
  def block_size(), do: @block_size

  def closest_block(%Coord{x: x, y: y, z: z}) do
    x = round(x / @block_size) * @block_size
    y = round(y / @block_size) * @block_size
    z = floor(z / @block_size) * @block_size
    %Coord{x: x, y: y, z: z}
  end

  def length(%Coord{x: x, y: y, z: z}) do
    :math.sqrt(x * x + y * y + z * z)
  end

  def add(left, right) when is_number(right) do
    %Coord{x: left.x + right, y: left.y + right, z: left.z + right}
  end

  def add(left, right) do
    %Coord{x: left.x + right.x, y: left.y + right.y, z: left.z + right.z}
  end

  def subtract(left, right) do
    %Coord{x: left.x - right.x, y: left.y - right.y, z: left.z - right.z}
  end

  def to_float(%{x: x, y: y, z: z}) do
    %Coord{x: x + 0.0, y: y + 0.0, z: z + 0.0}
  end
end
