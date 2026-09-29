defmodule Ms2ex.Collision do
  @moduledoc """
  Attack hit volumes. A skill attack's range doc describes a prism: a
  polygon footprint (box, cylinder, frustum or hole-cylinder) projected
  from an anchor position along a facing angle and raised over a height
  band. A position is inside the prism when its footprint point falls
  within the polygon and its height within the band.

  Ranges typed `none` carry no volume at all — no prism exists for them
  and nothing is ever inside.
  """

  @epsilon 1.0e-5

  alias Ms2ex.Types.Coord

  @type polygon ::
          {:trapezoid, [{number(), number()}]}
          | {:circle, {number(), number(), number()}}
          | {:hole_circle, {number(), number(), number(), number()}}
          | :none

  @type prism :: %{polygon: polygon(), base_z: number(), top_z: number()}

  # range type docs: 1 = box, 2 = cylinder, 3 = frustum, 4 = hole-cylinder
  @doc """
  Builds the hit-volume prism for a range doc anchored at `position`,
  facing `angle` (degrees, the caster's yaw). The facing rotates the
  footprint and the range's own rotate offset rides on top.
  """
  @spec build_prism(map(), Coord.t(), number()) :: prism()
  def build_prism(range, %Coord{} = position, angle) when is_map(range) do
    {origin_x, origin_y, base_z} = anchor(range, position)

    %{
      polygon: footprint(range, {origin_x, origin_y}, facing(range, angle)),
      base_z: base_z,
      top_z: base_z + height(range)
    }
  end

  # the volume shapes: a box projects forward as a trapezoid whose near
  # and far edges are equally wide, a frustum narrows from width to end
  # width, a cylinder is a circle, a hole-cylinder a ring
  defp footprint(range, {ox, oy}, facing) do
    case range[:type] do
      1 ->
        trapezoid(ox, oy, width(range), width(range), reach(range), facing)

      2 ->
        {:circle, {ox, oy, raw(range, :distance)}}

      3 ->
        trapezoid(
          ox,
          oy,
          raw(range, :width),
          raw(range, :end_width),
          raw(range, :distance),
          facing
        )

      4 ->
        {:hole_circle, {ox, oy, raw(range, :width), raw(range, :end_width)}}

      _ ->
        :none
    end
  end

  defp raw(range, key), do: range[key] || 0

  # a box's reach scales with its range_add; a frustum's shape is raw
  defp width(range), do: (range[:width] || 0) + (range[:range_add_x] || 0)
  defp reach(range), do: (range[:distance] || 0) + (range[:range_add_y] || 0)
  defp height(range), do: (range[:height] || 0) + (range[:range_add_z] || 0)

  defp facing(range, angle),
    do: :math.fmod((angle || 0) + (range[:rotate_z_degree] || 0) + 180, 360)

  defp anchor(range, position) do
    {
      position.x + (range[:range_offset_x] || 0),
      position.y + (range[:range_offset_y] || 0),
      position.z + (range[:range_offset_z] || 0)
    }
  end

  @doc "Whether a position falls inside the prism."
  @spec contains?(prism(), %{x: number(), y: number(), z: number()}) :: boolean()
  def contains?(%{polygon: :none}, _position), do: false

  def contains?(%{polygon: polygon, base_z: base_z, top_z: top_z}, %{x: x, y: y, z: z}) do
    base_z <= z and z <= top_z and polygon_contains?(polygon, x, y)
  end

  # a box projects forward as a trapezoid whose near and far edges are
  # equally wide; a frustum narrows (or widens) from width to end width
  defp trapezoid(ox, oy, near_width, far_width, distance, facing) do
    radians = facing * :math.pi() / 180
    cos = :math.cos(radians)
    sin = :math.sin(radians)

    points =
      [
        {-near_width / 2, 0},
        {near_width / 2, 0},
        {far_width / 2, distance},
        {-far_width / 2, distance}
      ]
      |> Enum.map(fn {lx, ly} -> {ox + lx * cos - ly * sin, oy + lx * sin + ly * cos} end)

    {:trapezoid, points}
  end

  # a point is inside a convex polygon when it sits on the same side of
  # every edge (the cross products against each segment share a sign)
  defp polygon_contains?({:trapezoid, points}, x, y) do
    {pos, neg} =
      Enum.reduce(0..(length(points) - 1), {0, 0}, fn i, {pos, neg} ->
        {x1, y1} = Enum.at(points, i)
        {x2, y2} = Enum.at(points, rem(i + 1, length(points)))

        d = (x - x1) * (y2 - y1) - (y - y1) * (x2 - x1)

        cond do
          d > @epsilon -> {pos + 1, neg}
          d < -@epsilon -> {pos, neg + 1}
          true -> {pos, neg}
        end
      end)

    pos == 0 or neg == 0
  end

  defp polygon_contains?({:circle, {cx, cy, radius}}, x, y) do
    dx = x - cx
    dy = y - cy
    dx * dx + dy * dy <= (radius + @epsilon) * (radius + @epsilon)
  end

  defp polygon_contains?({:hole_circle, {cx, cy, inner, outer}}, x, y) do
    polygon_contains?({:circle, {cx, cy, outer}}, x, y) and
      not polygon_contains?({:circle, {cx, cy, inner}}, x, y)
  end
end
