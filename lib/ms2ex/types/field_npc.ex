defmodule Ms2ex.Types.FieldNpc do
  alias Ms2ex.Types.Coord

  defstruct [
    :id,
    :npc,
    :field,
    :object_id,
    :position,
    :rotation,
    :spawn_point_id,
    :type,
    :stats,
    :last_attacker,
    animation: 255,
    dead?: false
  ]

  def new(attrs) do
    attrs =
      attrs
      |> Map.put(:position, struct(Coord, attrs.position || %{}))
      |> Map.put(:rotation, struct(Coord, attrs.rotation || %{}))
      |> Map.put(:type, get_type(attrs.npc))
      |> Map.put(:animation, 255)
      |> Map.put(:stats, attrs.npc.metadata.stat.stats)

    struct(__MODULE__, attrs)
  end

  def get_type(npc) do
    friendly = get_in(npc.metadata, [:basic, :friendly]) || 0

    if !friendly, do: :mob, else: :npc
  end
end
