defmodule Ms2ex.Crypto.Cipher do
  alias Ms2ex.Crypto.{Crypter, Rand32}
  alias Ms2ex.Crypto.RearrangeCrypter, as: RCrypter
  alias Ms2ex.Crypto.XorCrypter, as: XCrypter
  alias Ms2ex.Crypto.TableCrypter, as: TCrypter

  import Bitwise

  @header_size 6

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

  def iv_to_int(iv) do
    <<n::integer-size(32)>> = iv
    n
  end

  def advance_iv(cipher) do
    %{cipher | iv: Rand32.crt_rand(cipher.iv)}
  end

  def generate_iv() do
    :crypto.strong_rand_bytes(4)
  end

  def header_size(), do: @header_size

  def mask(n, bits \\ 32)
  def mask(n, 32), do: n &&& 0xFFFFFFFF
  def mask(n, 64), do: n &&& 0xFFFFFFFFFFFFFFFF
end
