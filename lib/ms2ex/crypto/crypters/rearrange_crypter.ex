defmodule Ms2ex.Crypto.RearrangeCrypter do
  @moduledoc """
  Implements a crypter that rearranges bytes in a packet.

  This crypter swaps bytes between the first and second halves of the packet data.
  The operation is symmetric, so encryption and decryption use the same algorithm.
  """

  import Bitwise

  @index 1

  @doc """
  Returns an empty string as the crypter requires no state.

  ## Returns
    * Empty string
  """
  @spec build() :: String.t()
  def build(), do: ""

  @doc """
  Returns the base index for this crypter.

  ## Returns
    * Index value
  """
  @spec index() :: non_neg_integer()
  def index(), do: @index

  @doc """
  Decrypts data by rearranging bytes.

  ## Parameters
    * `data` - List of bytes to decrypt

  ## Returns
    * Decrypted list of bytes
  """
  @spec decrypt(list(non_neg_integer())) :: list(non_neg_integer())
  def decrypt(data), do: encrypt_or_decrypt(data)

  @doc """
  Encrypts data by rearranging bytes.

  ## Parameters
    * `data` - List of bytes to encrypt

  ## Returns
    * Encrypted list of bytes
  """
  @spec encrypt(list(non_neg_integer())) :: list(non_neg_integer())
  def encrypt(data), do: encrypt_or_decrypt(data)

  defp encrypt_or_decrypt(data) do
    len = length(data) >>> 1

    Enum.reduce(0..(len - 1), data, fn idx, acc ->
      swap = Enum.at(acc, idx)

      acc
      |> List.update_at(idx, fn _ -> Enum.at(acc, idx + len) end)
      |> List.update_at(idx + len, fn _ -> swap end)
    end)
  end
end
