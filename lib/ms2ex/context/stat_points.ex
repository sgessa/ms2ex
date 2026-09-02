defmodule Ms2ex.Context.StatPoints do
  alias Ms2ex.Enums.BasicStatType
  alias Ms2ex.Schema

  # subset of BasicStatType stats that are allocatable via AP
  @ap_attributes ~w(strength dexterity intelligence luck health critical_rate)a

  def apply(%Schema.Character{} = character) do
    character.stat_point_allocation
    |> normalize_allocation()
    |> Enum.reduce(character, fn {attr, amount}, char ->
      apply_attribute(char, attr, amount)
    end)
  end

  def apply(character), do: character

  def normalize_allocation(allocation) when is_map(allocation) do
    Enum.reduce(allocation, %{}, fn {attr, amount}, acc ->
      case attribute(attr) do
        {:ok, stat} -> Map.put(acc, stat, amount)
        :error -> acc
      end
    end)
  end

  def normalize_allocation(_), do: %{}

  def attribute(a) when is_atom(a) and a in @ap_attributes, do: {:ok, a}

  def attribute(id) when is_integer(id) do
    stat = BasicStatType.get_key(id)
    if stat in @ap_attributes, do: {:ok, stat}, else: :error
  end

  def attribute(_), do: :error

  def apply_attribute(%Schema.Character{} = character, attribute, amount) do
    with {:ok, stat} <- attribute(attribute),
         {stat, delta} <- bonus(stat, amount) do
      add_stat(character, stat, delta)
    else
      _ -> character
    end
  end

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
