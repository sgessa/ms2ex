defmodule Ms2ex.Types.AttributePointSource do
  @type t :: :trophy | :quest | :exploration | :prestige | :command

  # matches C# AttributePointSource enum wire values
  @values %{trophy: 1, quest: 2, exploration: 3, prestige: 4, command: 5}
  @default_sources %{trophy: 0, quest: 0, exploration: 0, prestige: 0, command: 0}

  def all, do: Map.keys(@values)
  def all_map, do: @values
  def default_sources, do: @default_sources

  def get_value(source), do: Map.get(@values, source)

  def get_key(id), do: Enum.find_value(@values, fn {k, v} -> if v == id, do: k end)

  # Normalises a persisted map (atom or legacy integer keys) to a full atom-keyed map.
  def normalize(sources) when is_map(sources) do
    Enum.reduce(@values, %{}, fn {source, id}, acc ->
      amount = Map.get(sources, source, Map.get(sources, id, 0))
      Map.put(acc, source, amount)
    end)
  end

  def normalize(_), do: @default_sources
end
