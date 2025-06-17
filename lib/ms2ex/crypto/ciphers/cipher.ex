defmodule Ms2ex.Crypto.Cipher do
  @moduledoc """
  Core module handling the MapleStory 2 encryption protocol, providing methods for building
  cryptographic sequences and managing initialization vectors (IVs).

  This module coordinates the different crypters (Rearrange, Table, and XOR) and provides
  utility functions for cipher operations.
  """

  alias Ms2ex.Crypto.{Crypter, Rand32}
  alias Ms2ex.Crypto.RearrangeCrypter, as: RCrypter
  alias Ms2ex.Crypto.XorCrypter, as: XCrypter
  alias Ms2ex.Crypto.TableCrypter, as: TCrypter

  import Bitwise

  @header_size 6

  @typedoc "A cryptographic sequence used in the encryption process"
  @type crypt_seq :: [module() | struct()]

  @doc """
  Initializes a cryptographic sequence based on version and block IV.

  ## Parameters
    * `version` - Protocol version number
    * `block_iv` - Block initialization vector

  ## Returns
    * A list of crypter modules/structs in the proper sequence
  """
  @spec init_crypt_seq(non_neg_integer(), non_neg_integer()) :: crypt_seq()
  def init_crypt_seq(version, block_iv) do
    build_crypt_seq([], get_crypts(version), block_iv)
  end

  defp build_crypt_seq(crypt_seq, crypts, block_iv) when block_iv > 0 do
    crypter = Enum.at(crypts, rem(block_iv, 10))
    crypt_seq = if crypter, do: crypt_seq ++ [crypter], else: crypt_seq

    block_iv = floor(block_iv / 10)
    build_crypt_seq(crypt_seq, crypts, block_iv)
  end

  defp build_crypt_seq(crypt_seq, _crypts, _block_iv), do: crypt_seq

  defp get_crypts(version) do
    crypts = [nil, nil, nil, nil]

    r_crypter_idx = Crypter.get_index(version, RCrypter.index())
    table_crypter_idx = Crypter.get_index(version, TCrypter.index())
    xor_crypter_idx = Crypter.get_index(version, XCrypter.index())

    crypts
    |> List.update_at(r_crypter_idx, fn _ -> RCrypter end)
    |> List.update_at(table_crypter_idx, fn _ -> TCrypter.build(version) end)
    |> List.update_at(xor_crypter_idx, fn _ -> XCrypter.build(version) end)
  end

  @doc """
  Converts a binary IV to its integer representation.

  ## Parameters
    * `iv` - Binary initialization vector (4 bytes)

  ## Returns
    * Integer representation of the IV
  """
  @spec iv_to_int(binary()) :: non_neg_integer()
  def iv_to_int(iv) do
    <<n::integer-size(32)>> = iv
    n
  end

  @doc """
  Updates the IV in a cipher using the congruential random algorithm.

  ## Parameters
    * `cipher` - Cipher struct containing an IV

  ## Returns
    * Updated cipher with new IV
  """
  @spec advance_iv(struct()) :: struct()
  def advance_iv(cipher) do
    %{cipher | iv: Rand32.crt_rand(cipher.iv)}
  end

  @doc """
  Generates a cryptographically secure random IV (4 bytes).

  ## Returns
    * Binary initialization vector
  """
  @spec generate_iv() :: binary()
  def generate_iv() do
    :crypto.strong_rand_bytes(4)
  end

  @doc """
  Returns the header size used in the protocol.

  ## Returns
    * Header size in bytes
  """
  @spec header_size() :: non_neg_integer()
  def header_size(), do: @header_size

  @doc """
  Applies a bit mask to an integer of specified bit width.

  ## Parameters
    * `n` - Integer to mask
    * `bits` - Bit width (default: 32)

  ## Returns
    * Masked integer value
  """
  @spec mask(integer(), 32 | 64) :: non_neg_integer()
  def mask(n, bits \\ 32)
  def mask(n, 32), do: n &&& 0xFFFFFFFF
  def mask(n, 64), do: n &&& 0xFFFFFFFFFFFFFFFF
end
