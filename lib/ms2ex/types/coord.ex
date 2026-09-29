defmodule Ms2ex.Types.Coord do
  defstruct x: 0, y: 0, z: 0

  def sum(a, b) do
    a = to_map(a)
    b = to_map(b)

    coord =
      Enum.reduce(a, a, fn {x, _v}, coord ->
        Map.put(coord, x, a[x] + b[x])
      end)

    struct(__MODULE__, coord)
  end

  def rotate(offset, %{z: rotation_z}) do
    angle = rotation_z * :math.pi() / 180
    offset = to_map(offset)

    x = offset.x * :math.cos(angle) + offset.y * :math.sin(angle)
    y = offset.x * :math.sin(angle) - offset.y * :math.cos(angle)

    %__MODULE__{x: x, y: y, z: offset.z}
  end

  defp to_map(%__MODULE__{} = coord), do: Map.from_struct(coord)
  defp to_map(coord), do: coord

  # placement grid tile containing a position (150-unit world cells); a
  # missing coordinate falls on tile 0
  @grid_size 150

  def grid_key(nil), do: nil

  def grid_key(%__MODULE__{} = position) do
    {grid_coord(position.x), grid_coord(position.y), grid_coord(position.z)}
  end

  def grid_key(position) when is_map(position) do
    {grid_coord(position[:x]), grid_coord(position[:y]), grid_coord(position[:z])}
  end

  defp grid_coord(value) when is_number(value), do: round(value / @grid_size)
  defp grid_coord(_), do: 0
end

defmodule Ms2ex.Types.CoordF do
  defstruct x: 0.0, y: 0.0, z: 0.0
end
