defmodule Ms2ex.Types.Npc do
  defstruct [
    :id,
    :metadata,
    boss?: false,
    animations: %{}
  ]

  def new(attrs) do
    friendly = get_in(attrs, [:metadata, :basic, :friendly]) || 0
    class = get_in(attrs, [:metadata, :basic, :class]) || 0

    is_boss? = friendly == 0 && class >= 3
    struct(__MODULE__, Map.put(attrs, :boss, is_boss?))
  end
end
