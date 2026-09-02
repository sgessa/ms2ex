defmodule Ms2ex.Types.AttributePointSource do
  use Ms2ex.Enum,
      %{
        trophy: 1,
        quest: 2,
        exploration: 3,
        prestige: 4,
        command: 5
      }

  @default_sources %{trophy: 0, quest: 0, exploration: 0, prestige: 0, command: 0}

  def default_sources, do: @default_sources

  # Normalises a persisted map (atom or legacy integer keys) to a full atom-keyed map.
  def normalize(sources) when is_map(sources) do
    Enum.reduce(all_map(), %{}, fn {source, id}, acc ->
      amount = Map.get(sources, source, Map.get(sources, id, 0))
      Map.put(acc, source, amount)
    end)
  end

  def normalize(_), do: @default_sources
end
