defmodule Ms2ex.Types.FieldNpc do
  defstruct [
    :id,
    :npc,
    :object_id,
    :position,
    :rotation,
    :spawn_point_id,
    animation: 255,
    dead?: false
  ]

  def new(attrs) do
    friendly = get_in(attrs, [:metadata, :basic, :friendly]) || 0
    is_boss? = friendly == 0 && friendly >= 3
    struct(__MODULE__, Map.put(attrs, :boss?, is_boss?))
  end
end
