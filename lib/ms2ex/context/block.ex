defmodule Ms2ex.MapBlock do
  alias Ms2ex.Metadata
  alias Metadata.Coord

  @block_size 150
  def block_size(), do: @block_size

  def closest_block(%Coord{x: x, y: y, z: z}) do
    x = floor((x + 75) / @block_size) * @block_size
    y = floor((y + 75) / @block_size) * @block_size
    z = floor((z + 75) / @block_size) * @block_size
    %Coord{x: x, y: y, z: z}
  end

  def exists?(map_id, block) do
    blocks = Metadata.MapBlocks.lookup(map_id)

    if Enum.find(blocks, &(block == &1)) do
      true
    else
      false
    end
  end

  def length(%Coord{x: x, y: y, z: z}) do
    :math.sqrt(x * x + y * y + z * z)
  end

  def subtract(%Coord{} = left, %Coord{} = right) do
    %Coord{x: left.x - right.x, y: left.y - right.y, z: left.z - right.z}
  end

  def to_float(%{x: x, y: y, z: z}) do
    Coord.new(x: x + 0.0, y: y + 0.0, z: z + 0.0)
  end
end
