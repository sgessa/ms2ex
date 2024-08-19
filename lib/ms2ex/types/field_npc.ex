defmodule Ms2ex.Types.FieldNpc do
  alias Ms2ex.Types.Coord
  alias Ms2ex.Enums
  alias Ms2ex.Context

  defstruct [
    :object_id,
    :npc,
    :field,
    :position,
    :rotation,
    :spawn_point_id,
    :type,
    :stats,
    :last_attacker,
    animation: 255,
    dead?: false,
    send_control?: true
  ]

  def build(attrs) do
    attrs =
      attrs
      |> Map.put(:rotation, struct(Coord, attrs.rotation || %{}))
      |> Map.put(:type, get_type(attrs.npc))
      |> Map.put(:animation, 255)
      |> Map.put(:stats, build_stats(attrs.npc.metadata.stat.stats))
      |> randomize_pos()

    struct(__MODULE__, attrs)
  end

  def get_type(npc) do
    friendly = get_in(npc.metadata, [:basic, :friendly]) || 0

    if friendly > 0, do: :npc, else: :mob
  end

  @spawn_distance 250
  defp randomize_pos(%{type: :mob} = attrs) do
    position = struct(Coord, attrs.position || %{})

    min_x = position.x - @spawn_distance
    max_x = position.x + @spawn_distance

    min_y = position.y - @spawn_distance
    max_y = position.y + @spawn_distance

    x = Context.Utils.rand_float(min_x, max_x)
    y = Context.Utils.rand_float(min_y, max_y)

    Map.put(attrs, :position, %{position | x: x, y: y})
  end

  defp randomize_pos(attrs) do
    position = struct(Coord, attrs.position || %{})

    Map.put(attrs, :position, position)
  end

  defp build_stats(stats) do
    Enums.BasicStatType.all()
    |> Enum.map(fn stat -> {stat, 0} end)
    |> Map.new()
    |> Map.merge(stats)
    |> Enum.map(fn {stat, value} ->
      {stat,
       %{
         total: value,
         base: value,
         current: value
       }}
    end)
    |> Map.new()
  end
end
