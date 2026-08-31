defmodule Ms2ex.Types.FieldNpc do
  alias Ms2ex.Types.Coord
  alias Ms2ex.Enums
  alias Ms2ex.Context

  @type t :: %__MODULE__{}

  defstruct [
    :object_id,
    :npc,
    :field,
    :position,
    :rotation,
    :spawn_point_id,
    :type,
    :stats,
    :first_attacker,
    :last_attacker,
    :damage_dealers,
    # TODO per-model sequence ids from anikey data (ingest projection)
    animation: 255,
    dead?: false,
    corpse?: false,
    send_control?: true,
    seq_counter: 0,
    last_control_at: 0
  ]

  # must match @idle_control_ms in Managers.Field; staggering keeps npcs from
  # all becoming dirty on the same tick
  @idle_control_ms 30

  def new(attrs) do
    attrs =
      attrs
      |> Map.put(:rotation, to_coord(attrs.rotation))
      |> Map.put(:type, get_type(attrs.npc))
      |> Map.put(:animation, 255)
      |> Map.put(:stats, build_stats(attrs.npc.metadata.stat.stats))
      |> Map.put_new(
        :last_control_at,
        System.monotonic_time(:millisecond) + :rand.uniform(@idle_control_ms)
      )
      |> Map.put_new(:damage_dealers, %{})
      |> randomize_pos()

    struct(__MODULE__, attrs)
  end

  defp to_coord(%Coord{} = coord), do: coord
  defp to_coord(nil), do: struct(Coord, %{})
  defp to_coord(map), do: struct(Coord, map)

  def get_type(npc) do
    friendly = get_in(npc.metadata, [:basic, :friendly]) || 0

    if friendly > 0, do: :npc, else: :mob
  end

  @spawn_distance 250
  defp randomize_pos(%{type: :mob} = attrs) do
    position = to_coord(attrs.position)

    min_x = position.x - @spawn_distance
    max_x = position.x + @spawn_distance

    min_y = position.y - @spawn_distance
    max_y = position.y + @spawn_distance

    x = Context.Utils.rand_float(min_x, max_x)
    y = Context.Utils.rand_float(min_y, max_y)

    Map.put(attrs, :position, %{position | x: x, y: y})
  end

  defp randomize_pos(attrs) do
    Map.put(attrs, :position, to_coord(attrs.position))
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
