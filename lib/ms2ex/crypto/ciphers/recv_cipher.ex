defmodule Ms2ex.Crypto.RecvCipher do
  alias Ms2ex.Crypto.{Cipher, RearrangeCrypter, TableCrypter, XorCrypter}
  alias Ms2ex.Packets.PacketReader

  require Logger, as: L

  import Bitwise

  defstruct [:version, :iv, :crypt_seq]

  def build(version, iv, block_iv) do
    crypt_seq =
      version
      |> Cipher.init_crypt_seq(block_iv)
      |> Enum.reverse()

    %__MODULE__{version: version, iv: iv, crypt_seq: crypt_seq}
  end

  def decrypt(%__MODULE__{} = cipher, data) do
    {cipher, packet} = read_header(cipher, data)

    packet =
      Enum.reduce(cipher.crypt_seq, :binary.bin_to_list(packet), fn crypter, acc ->
        _decrypt(crypter, acc)
      end)

    {cipher, :binary.list_to_bin(packet)}
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
    # IO.inspect(enc_seq, label: "[RECV] ENC SEQ")
    # IO.inspect(cipher.iv, label: "[RECV] IV")
    dec_seq = (cipher.iv >>> 16) ^^^ enc_seq
    # IO.inspect(dec_seq, label: "[RECV] DEC SEQ")

    cipher = Cipher.advance_iv(cipher)
    {cipher, dec_seq}
  end

  defp _decrypt(RearrangeCrypter, data), do: RearrangeCrypter.decrypt(data)
  defp _decrypt(%TableCrypter{} = tc, data), do: TableCrypter.decrypt(tc, data)
  defp _decrypt(%XorCrypter{} = xc, data), do: XorCrypter.decrypt(xc, data)
end
