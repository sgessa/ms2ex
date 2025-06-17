defmodule Ms2ex.Crypto.XorCrypter do
  @moduledoc """
  Implements a XOR-based crypter.

  This crypter applies XOR operations with values derived from the protocol version
  to encrypt and decrypt data.
  """

  alias Ms2ex.Crypto.Rand32

  import Bitwise

  @typedoc "XOR crypter state containing a table of values"
  @type t :: %__MODULE__{
          table: list(float())
        }

  defstruct table: []

  @index 2

  @doc """
  Builds a XOR crypter with values derived from the protocol version.

  ## Parameters
    * `version` - Protocol version

  ## Returns
    * XOR crypter struct
  """
  @spec build(non_neg_integer()) :: t()
  def build(version) do
    {_rand32, rand_float} =
      version
      |> Rand32.build()
      |> Rand32.random_float()

    {_rand32, rand2_float} =
      (version * 2)
      |> Rand32.build()
      |> Rand32.random_float()

    %__MODULE__{
      table: [rand_float * 255, rand2_float * 255]
    }
  end

  @doc """
  Returns the base index for this crypter.

  ## Returns
    * Index value
  """
  @spec index() :: non_neg_integer()
  def index(), do: @index

  @doc """
  Decrypts data using XOR operations.

  ## Parameters
    * `xc` - XOR crypter struct
    * `data` - List of bytes to decrypt

  ## Returns
    * Decrypted list of bytes
  """
  @spec decrypt(t(), list(non_neg_integer())) :: list(non_neg_integer())
  def decrypt(%__MODULE__{} = xc, data), do: encrypt_or_decrypt(xc, data)

  @doc """
  Encrypts data using XOR operations.

  ## Parameters
    * `xc` - XOR crypter struct
    * `data` - List of bytes to encrypt

  ## Returns
    * Encrypted list of bytes
  """
  @spec encrypt(t(), list(non_neg_integer())) :: list(non_neg_integer())
  def encrypt(%__MODULE__{} = xc, data), do: encrypt_or_decrypt(xc, data)

  defp encrypt_or_decrypt(xc, data) do
    Enum.reduce(0..(length(data) - 1), data, fn idx, acc ->
      table = Enum.at(xc.table, idx &&& 1)
      List.update_at(acc, idx, &bxor(&1, table))
    end)
  end
end
