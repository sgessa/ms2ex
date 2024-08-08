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

  defp to_map(%__MODULE__{} = coord), do: Map.from_struct(coord)
  defp to_map(coord), do: coord
end

defmodule Ms2ex.Types.CoordF do
  defstruct x: 0.0, y: 0.0, z: 0.0
end
