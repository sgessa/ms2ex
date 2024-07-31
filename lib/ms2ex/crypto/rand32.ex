defmodule Ms2ex.Crypto.Rand32 do
  import Bitwise

  alias Ms2ex.Crypto.Cipher

  def build(seed) do
    rand = crt_rand(seed)
    rand2 = crt_rand(rand)

    {
      :rand32,
      (Cipher.mask(seed) ||| 0x100000) >>> 0,
      (Cipher.mask(rand) ||| 0x1000) >>> 0,
      (Cipher.mask(rand2) ||| 0x10) >>> 0
    }
  end

  def crt_rand(seed) do
    Cipher.mask(214_013 * seed + 2_531_011) >>> 0
  end

  def random({:rand32, s1, s2, s3}) do
    s1 = (s1 <<< 12 &&& 0xFFFFE000) |> bxor(s1 >>> 6 &&& 0x00001FFF) |> bxor(s1 >>> 19)
    s2 = (s2 <<< 4 &&& 0xFFFFFF80) |> bxor(s2 >>> 23 &&& 0x0000007F) |> bxor(s2 >>> 25)
    s3 = (s3 <<< 17 &&& 0xFFE00000) |> bxor(s3 >>> 8 &&& 0x001FFFFF) |> bxor(s3 >>> 11)

    rand32 = {:rand32, s1, s2, s3}
    rand = s1 |> bxor(s2) |> bxor(s3)
    {rand32, rand >>> 0}
  end

  def random_float(rand32) do
    {rand32, rand} = random(rand32)
    bits = (rand &&& 0x007FFFFF) ||| 0x3F800000
    <<n::integer-size(32)>> = get_bytes(bits)
    {rand32, n - 1}
  end

  defp get_bytes(n) do
    <<n, n >>> 8, n >>> 16, n >>> 24>>
  end
end
