defmodule Ms2ex.Crypto.Cipher do
  @moduledoc """
  Core module handling the MapleStory 2 encryption protocol, providing methods for building
  cryptographic sequences and managing initialization vectors (IVs).

  The crypter sequence and payload transforms run in the native crypto library
  (`Ms2ex.Crypto.Native`); this module keeps the IV handling and header sizing.
  """

  alias Ms2ex.Crypto.Native

  @header_size 6

  @typedoc "A cryptographic sequence used in the encryption process"
  @type crypt_seq :: Native.crypt_seq()

  @doc """
  Initializes a cryptographic sequence based on version and block IV.

  ## Parameters
    * `version` - Protocol version number
    * `block_iv` - Block initialization vector

  ## Returns
    * A crypter sequence in the order defined by the block IV digits
  """
  @spec init_crypt_seq(non_neg_integer(), non_neg_integer()) :: crypt_seq()
  def init_crypt_seq(version, block_iv) do
    Native.crypt_seq(version, block_iv)
  end

  @doc """
  Converts a binary IV to its integer representation.

  ## Parameters
    * `iv` - Binary initialization vector (4 bytes)

  ## Returns
    * Unsigned integer representation of the IV
  """
  @spec iv_to_int(binary()) :: non_neg_integer()
  def iv_to_int(iv) do
    <<n::unsigned-integer-size(32)>> = iv
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
    %{cipher | iv: Native.crt_rand(cipher.iv)}
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
end
