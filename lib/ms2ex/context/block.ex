defmodule Ms2ex.MapBlock do
  alias Ms2ex.Metadata
  alias Ms2ex.Structs.Coord

  @block_size 150
  def block_size(), do: @block_size

  def closest_block(%Coord{x: x, y: y, z: z}) do
    x = round(x / @block_size) * @block_size
    y = round(y / @block_size) * @block_size
    z = floor(z / @block_size) * @block_size
    %Coord{x: x, y: y, z: z}
  end

  def exists?(field_id, block) do
    map = Metadata.get(Metadata.Map, field_id)

    Metadata.MapEntity
    |> Metadata.filter("#{map.x_block}_*")
    |> Enum.any?(&(Map.get(&1.block, :position) == block))
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
