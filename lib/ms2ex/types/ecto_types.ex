defmodule Ms2ex.EctoTypes.Term do
  use Ecto.Type

  def type, do: :binary
  def cast(term), do: {:ok, term}
  def load(binary), do: {:ok, :erlang.binary_to_term(binary)}
  def dump(term), do: {:ok, :erlang.term_to_binary(term)}
end

defmodule Ms2ex.EctoTypes.TransferFlags do
  use Ecto.Type

  alias Ms2ex.TransferFlags

  # stored as an integer bitmask; contexts only ever see the flag atoms
  def type, do: :integer
  def cast(names) when is_list(names), do: {:ok, names}
  def cast(_), do: :error
  def dump(names) when is_list(names), do: {:ok, TransferFlags.to_int(names)}
  def dump(_), do: :error
  def load(flags) when is_integer(flags), do: {:ok, TransferFlags.from_int(flags)}
  def load(_), do: :error
end
