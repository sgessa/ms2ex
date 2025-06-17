defmodule Ms2ex.Crypto.TableCrypter do
  @moduledoc """
  Implements a table-based substitution crypter.

  This crypter uses a shuffled table based on the protocol version to perform
  substitution encryption and decryption.
  """

  alias Ms2ex.Crypto.Rand32

  @typedoc "Table crypter state containing encryption and decryption tables"
  @type t :: %__MODULE__{
          encrypted: list(non_neg_integer()),
          decrypted: list(non_neg_integer())
        }

  defstruct encrypted: [], decrypted: []

  @index 3
  @table_size 256

  @doc """
  Builds a table crypter with encryption and decryption tables based on version.

  ## Parameters
    * `version` - Protocol version

  ## Returns
    * Table crypter struct
  """
  @spec build(non_neg_integer()) :: t()
  def build(version) do
    {encrypted, _rand32} =
      0..(@table_size - 1)
      |> Enum.into([])
      |> shuffle(version)

    decrypted = List.duplicate(nil, @table_size)

    decrypted =
      Enum.reduce(0..(@table_size - 1), decrypted, fn idx, acc ->
        enc_idx = Enum.at(encrypted, idx)
        List.update_at(acc, enc_idx, fn _ -> idx end)
      end)

    %__MODULE__{encrypted: encrypted, decrypted: decrypted}
  end

  @doc """
  Returns the base index for this crypter.

  ## Returns
    * Index value
  """
  @spec index() :: non_neg_integer()
  def index(), do: @index

  @doc """
  Decrypts data using the decryption table.

  ## Parameters
    * `tc` - Table crypter struct
    * `data` - List of bytes to decrypt

  ## Returns
    * Decrypted list of bytes
  """
  @spec decrypt(t(), list(non_neg_integer())) :: list(non_neg_integer())
  def decrypt(%__MODULE__{} = tc, data) do
    Enum.map(data, fn x ->
      Enum.at(tc.decrypted, x)
    end)
  end

  @doc """
  Encrypts data using the encryption table.

  ## Parameters
    * `tc` - Table crypter struct
    * `data` - List of bytes to encrypt

  ## Returns
    * Encrypted list of bytes
  """
  @spec encrypt(t(), list(non_neg_integer())) :: list(non_neg_integer())
  def encrypt(%__MODULE__{} = tc, data) do
    Enum.map(data, fn x ->
      Enum.at(tc.encrypted, x)
    end)
  end

  defp shuffle(data, version) do
    seed =
      version
      |> :math.pow(2)
      |> trunc()

    rand32 = Rand32.build(seed)

    Enum.reduce((@table_size - 1)..0, {data, rand32}, fn idx, {data, rand32} ->
      {rand32, rand} = Rand32.random(rand32)

      rand_idx = rem(rand, idx + 1)

      swap = Enum.at(data, idx)
      rand = Enum.at(data, rand_idx)

      data =
        data
        |> List.update_at(idx, fn _ -> rand end)
        |> List.update_at(rand_idx, fn _ -> swap end)

      {data, rand32}
    end)
  end
end
