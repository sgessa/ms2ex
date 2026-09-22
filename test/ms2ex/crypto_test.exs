defmodule Ms2ex.CryptoTest do
  use ExUnit.Case, async: true

  alias Ms2ex.Crypto.Cipher
  alias Ms2ex.Crypto.Native
  alias Ms2ex.Crypto.RecvCipher
  alias Ms2ex.Crypto.SendCipher

  # pinned crypto vectors: crt_rand outputs, crypter tables and whole frames
  # used to verify the native implementation byte-for-byte across seeds,
  # versions and block IVs (including a high-bit IV and repeated digits)
  @vectors "test/fixtures/crypto/reference_vectors.json"
           |> File.read!()
           |> JSON.decode!()

  describe "crt_rand/1" do
    test "matches the reference congruential step" do
      for %{"seed" => seed, "value" => value} <- @vectors["crt_rand"] do
        assert Native.crt_rand(String.to_integer(seed)) == String.to_integer(value)
      end
    end

    test "wraps on the 32-bit boundary" do
      assert Native.crt_rand(4_294_967_295) == 2_316_998
    end
  end

  describe "crypt_seq/2" do
    test "builds the reference substitution tables" do
      for %{"version" => version, "encrypted" => encrypted, "decrypted" => decrypted} <-
            @vectors["tables"] do
        assert {:table, enc_table, dec_table} = table_crypter(version)
        assert enc_table == decode_hex(encrypted)
        assert dec_table == decode_hex(decrypted)
      end
    end

    test "builds the reference xor tables" do
      for %{"version" => version, "table0" => t0, "table1" => t1} <- @vectors["xor_tables"] do
        assert xor_crypter(version) == {:xor, t0, t1}
      end
    end

    test "applies a crypter once per matching block IV digit" do
      # version 12: rearrange occupies slot 2, table slot 1, xor slot 3
      assert Cipher.init_crypt_seq(12, 12) == [:rearrange, table_crypter(12)]
      # repeated digits repeat the crypter
      assert Cipher.init_crypt_seq(12, 22) == [:rearrange, :rearrange]
      assert Cipher.init_crypt_seq(12, 3) == [xor_crypter(12)]

      assert Cipher.init_crypt_seq(12, 321) == [
               table_crypter(12),
               :rearrange,
               xor_crypter(12)
             ]
    end
  end

  describe "transform/3" do
    test "rearrange swaps packet halves and is its own inverse" do
      data = <<1, 2, 3, 4, 5, 6>>
      swapped = Native.transform([:rearrange], data, true)

      assert swapped == <<4, 5, 6, 1, 2, 3>>
      assert Native.transform([:rearrange], swapped, false) == data
    end

    test "xor alternates its two table bytes and is its own inverse" do
      data = <<0, 0, 0, 0>>
      encrypted = Native.transform([{:xor, 84, 195}], data, true)

      assert encrypted == <<84, 195, 84, 195>>
      assert Native.transform([{:xor, 84, 195}], encrypted, false) == data
    end

    test "table substitution round-trips through the inverse table" do
      {:table, enc_table, dec_table} = table_crypter(12)
      data = <<0, 17, 255, 128>>
      encrypted = Native.transform([{:table, enc_table, dec_table}], data, true)

      assert Native.transform([{:table, enc_table, dec_table}], encrypted, false) == data
    end
  end

  describe "frames" do
    test "encrypts byte-for-byte like the reference" do
      for %{
            "version" => version,
            "iv" => iv,
            "block_iv" => block_iv,
            "payload" => payload,
            "frame" => frame
          } <- @vectors["frames"] do
        iv = String.to_integer(iv)
        cipher = SendCipher.build(version, iv, block_iv)
        {cipher, encrypted} = SendCipher.encrypt(cipher, decode_hex(payload))

        assert encrypted == decode_hex(frame)
        # the header consumed the first IV
        assert cipher.iv == Native.crt_rand(iv)
      end
    end

    test "decrypts reference frames back to their payload" do
      for %{
            "version" => version,
            "iv" => iv,
            "block_iv" => block_iv,
            "payload" => payload,
            "frame" => frame
          } <- @vectors["frames"] do
        iv = String.to_integer(iv)
        cipher = RecvCipher.build(version, iv, block_iv)
        {cipher, packet} = RecvCipher.decrypt(cipher, decode_hex(frame))

        assert packet == decode_hex(payload)
        assert cipher.iv == Native.crt_rand(iv)
      end
    end

    test "round-trips an empty payload" do
      cipher = SendCipher.build(12, 424_242, 12)
      {cipher, frame} = SendCipher.encrypt(cipher, <<>>)

      assert byte_size(frame) == Cipher.header_size()

      recv_cipher = RecvCipher.build(12, 424_242, 12)
      {_recv_cipher, <<>>} = RecvCipher.decrypt(recv_cipher, frame)

      assert cipher.iv == Native.crt_rand(424_242)
    end
  end

  defp decode_hex(hex), do: Base.decode16!(hex, case: :upper)

  defp table_crypter(version) do
    Enum.find(Cipher.init_crypt_seq(version, 1), &match?({:table, _, _}, &1))
  end

  defp xor_crypter(version) do
    Enum.find(Cipher.init_crypt_seq(version, 3), &match?({:xor, _, _}, &1))
  end
end
