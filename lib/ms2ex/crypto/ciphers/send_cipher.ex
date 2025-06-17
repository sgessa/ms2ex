defmodule Ms2ex.Crypto.SendCipher do
  @moduledoc """
  Handles encryption of outgoing packets in the MapleStory 2 protocol.

  This module manages packet encryption and header writing for data being sent
  to the client.
  """

  alias Ms2ex.Crypto.{Cipher, RearrangeCrypter, TableCrypter, XorCrypter}

  import Bitwise
  import Ms2ex.Packets.PacketWriter

  @typedoc "Send cipher state containing version, IV, and cryptographic sequence"
  @type t :: %__MODULE__{
          version: non_neg_integer(),
          iv: non_neg_integer(),
          crypt_seq: [module() | struct()]
        }

  defstruct [:version, :iv, :crypt_seq]

  @doc """
  Creates a new send cipher with the specified parameters.

  ## Parameters
    * `version` - Protocol version
    * `iv` - Initialization vector as integer
    * `block_iv` - Block initialization vector

  ## Returns
    * New send cipher struct
  """
  @spec build(non_neg_integer(), non_neg_integer(), non_neg_integer()) :: t()
  def build(version, iv, block_iv) do
    crypt_seq = Cipher.init_crypt_seq(version, block_iv)
    %__MODULE__{version: version, iv: iv, crypt_seq: crypt_seq}
  end

  @doc """
  Writes the protocol header to a packet and updates the send cipher.

  ## Parameters
    * `send_cipher` - Current send cipher state
    * `packet` - Binary packet data

  ## Returns
    * `{updated_send_cipher, packet_with_header}` - Tuple with updated state and packet
  """
  @spec write_header(t(), binary()) :: {t(), binary()}
  def write_header(send_cipher, packet) do
    {send_cipher, enc_seq} = encode_seq_base(send_cipher)

    header =
      ""
      |> put_ushort(enc_seq)
      |> put_int(byte_size(packet))

    {send_cipher, header <> packet}
  end

  defp encode_seq_base(send_cipher) do
    enc_seq = bxor(send_cipher.version, Cipher.mask(send_cipher.iv >>> 16))
    send_cipher = Cipher.advance_iv(send_cipher)
    {send_cipher, enc_seq}
  end

  @doc """
  Encrypts a binary packet and adds the header.

  ## Parameters
    * `cipher` - Current send cipher state
    * `packet` - Raw binary packet to encrypt

  ## Returns
    * `{updated_cipher, encrypted_packet}` - Tuple with updated state and packet
  """
  @spec encrypt(t(), binary()) :: {t(), binary()}
  def encrypt(%__MODULE__{} = cipher, packet) do
    packet =
      Enum.reduce(cipher.crypt_seq, :binary.bin_to_list(packet), fn crypter, acc ->
        _encrypt(crypter, acc)
      end)

    packet = :binary.list_to_bin(packet)
    write_header(cipher, packet)
  end

  defp _encrypt(RearrangeCrypter, data), do: RearrangeCrypter.encrypt(data)
  defp _encrypt(%TableCrypter{} = tc, data), do: TableCrypter.encrypt(tc, data)
  defp _encrypt(%XorCrypter{} = xc, data), do: XorCrypter.encrypt(xc, data)
end
