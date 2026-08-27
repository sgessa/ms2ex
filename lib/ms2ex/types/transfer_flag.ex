defmodule Ms2ex.TransferFlags do
  import Bitwise

  @values [{:split, 2}, {:trade, 4}, {:bind, 8}, {:limit_trade, 16}]
  @value_map Map.new(@values)

  @doc """
  Combines a list of flag atoms into its integer bitmask.

  ## Examples

      iex> to_int([:trade, :split])
      6
  """
  def to_int(names) when is_list(names) do
    Enum.reduce(names, 0, fn name, acc -> acc ||| Map.get(@value_map, name, 0) end)
  end

  @doc """
  Decodes an integer bitmask into its flag atoms.

  ## Examples

      iex> from_int(6)
      [:split, :trade]
  """
  def from_int(flags) when is_integer(flags) do
    for {name, value} <- @values, band(flags, value) != 0, do: name
  end

  @doc """
  Whether an integer bitmask carries the given flag.

  ## Examples

      iex> has_flag?(6, :trade)
      true
  """
  def has_flag?(flags, name) when is_integer(flags) do
    band(flags, Map.get(@value_map, name, 0)) != 0
  end
end
