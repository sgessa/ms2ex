defmodule Ms2ex.Crypto.RecvCipher do
  @moduledoc """
  Handles decryption of incoming packets in the MapleStory 2 encryption protocol.

  This module manages packet header parsing and decryption for data received
  from the client. The payload transform runs in the native crypto library,
  applied in the reverse of the send order.
  """

  alias Ms2ex.Crypto.Cipher
  alias Ms2ex.Crypto.Native
  alias Ms2ex.Packets.PacketReader

  require Logger, as: L

  import Bitwise

  @typedoc "Receive cipher state containing version, IV, and cryptographic sequence"
  @type t :: %__MODULE__{
          version: non_neg_integer(),
          iv: non_neg_integer(),
          crypt_seq: Cipher.crypt_seq()
        }

  defstruct [:version, :iv, :crypt_seq]

  @doc """
  Creates a new receive cipher with the specified parameters.

  ## Parameters
    * `version` - Protocol version
    * `iv` - Initialization vector as integer
    * `block_iv` - Block initialization vector

  ## Returns
    * New receive cipher struct
  """
  @spec build(non_neg_integer(), non_neg_integer(), non_neg_integer()) :: t()
  def build(version, iv, block_iv) do
    crypt_seq =
      version
      |> Cipher.init_crypt_seq(block_iv)
      |> Enum.reverse()

    %__MODULE__{version: version, iv: iv, crypt_seq: crypt_seq}
  end

  @doc """
  Decrypts a binary packet by first parsing the header and then applying the decryption sequence.

  ## Parameters
    * `cipher` - Current receive cipher state
    * `data` - Binary packet data to decrypt

  ## Returns
    * `{updated_cipher, decrypted_packet}` - Tuple with updated state and packet
  """
  @spec decrypt(t(), binary()) :: {t(), binary()}
  def decrypt(%__MODULE__{} = cipher, data) do
    {cipher, packet} = read_header(cipher, data)
    {cipher, Native.transform(cipher.crypt_seq, packet, false)}
  end

  defp read_header(cipher, packet) do
    size = byte_size(packet)

    {enc_seq, packet} = PacketReader.get_ushort(packet)
    {cipher, dec_seq} = decode_seq_base(cipher, enc_seq)

    if dec_seq != cipher.version do
      L.error("Packet has invalid sequence header: #{dec_seq}")
    end

    {plen, packet} = PacketReader.get_int(packet)

    if size < plen + Cipher.header_size() do
      L.error("Packet has invalid length: #{size}")
    end

    {cipher, packet}
  end

  defp decode_seq_base(cipher, enc_seq) do
    dec_seq = bxor(cipher.iv >>> 16, enc_seq)

    cipher = Cipher.advance_iv(cipher)
    {cipher, dec_seq}
  end
end
