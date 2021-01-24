defmodule Ms2ex.Crypto.SendCipher do
  alias Ms2ex.Crypto.{Cipher, RearrangeCrypter, TableCrypter, XorCrypter}

  import Bitwise
  import Ms2ex.Packets.PacketWriter

  defstruct [:version, :iv, :crypt_seq]

  def build(version, iv, block_iv) do
    crypt_seq = Cipher.init_crypt_seq(version, block_iv)
    %__MODULE__{version: version, iv: iv, crypt_seq: crypt_seq}
  end

  def write_header(send_cipher, packet) do
    {send_cipher, enc_seq} = encode_seq_base(send_cipher)

    header =
      ""
      |> put_ushort(enc_seq)
      |> put_int(byte_size(packet))

    {send_cipher, header <> packet}
  end

  defp encode_seq_base(send_cipher) do
    enc_seq = send_cipher.version ^^^ Cipher.mask(send_cipher.iv >>> 16)
    send_cipher = Cipher.advance_iv(send_cipher)
    {send_cipher, enc_seq}
  end

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
