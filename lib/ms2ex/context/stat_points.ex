defmodule Ms2ex.Context.StatPoints do
  alias Ms2ex.Schema

  @attributes %{
    strength: 0,
    dexterity: 1,
    intelligence: 2,
    luck: 3,
    health: 4,
    critical_rate: 17
  }

  @doc "Applies all persisted allocated AP to a character's stats (called during full stat rebuild)."
  def apply(%Schema.Character{} = character) do
    character.stat_point_allocation
    |> normalize_allocation()
    |> Enum.reduce(character, fn {attr, amount}, char ->
      apply_attribute(char, attr, amount)
    end)
  end

  def apply(character), do: character

  @doc "Normalises an allocation map, accepting atom or legacy integer keys."
  def normalize_allocation(allocation) when is_map(allocation) do
    Enum.reduce(allocation, %{}, fn {attr, amount}, acc ->
      case attribute(attr) do
        {:ok, stat} -> Map.put(acc, stat, amount)
        :error -> acc
      end
    end)
  end

  def normalize_allocation(_), do: %{}

  @doc "Returns `{:ok, atom}` for a known attribute given an atom or wire integer."
  def attribute(a) when is_atom(a) do
    if Map.has_key?(@attributes, a), do: {:ok, a}, else: :error
  end

  def attribute(id) when is_integer(id) do
    case Enum.find(@attributes, fn {_k, v} -> v == id end) do
      {stat, _} -> {:ok, stat}
      nil -> :error
    end
  end

  def attribute(_), do: :error

  @doc "Returns the wire byte ID for a stat atom."
  def attribute_id(stat), do: Map.get(@attributes, stat)

  @doc "Applies a single attribute delta to the character's in-memory stats."
  def apply_attribute(%Schema.Character{} = character, attribute, amount)
      when is_integer(amount) do
    with {:ok, stat} <- attribute(attribute),
         {stat, delta} <- bonus(stat, amount) do
      add_stat(character, stat, delta)
    else
      _ -> character
    end
  end

  def apply_attribute(character, _attribute, _amount), do: character

  # health +10 per point, critical_rate +3 per point
  defp bonus(:health, amount), do: {:health, amount * 10}
  defp bonus(:critical_rate, amount), do: {:critical_rate, amount * 3}
  defp bonus(stat, amount), do: {stat, amount}

  defp add_stat(character, stat, amount) do
    stats =
      character.stats
      |> Map.update(:"#{stat}_max", amount, &(&1 + amount))
      |> Map.update(:"#{stat}_cur", amount, &(&1 + amount))

    %{character | stats: stats}
  end
end
