defmodule Ms2ex.Crypto.Rand32 do
  @moduledoc """
  Implements a 32-bit random number generator used in the MapleStory 2 encryption protocol.

  This module provides functionality to create and manipulate random number states based on seeds,
  as well as generate random integers and floats from those states.
  """

  import Bitwise

  alias Ms2ex.Crypto.Cipher

  @typedoc "Random number generator state"
  @type rand32 :: {:rand32, non_neg_integer(), non_neg_integer(), non_neg_integer()}
  @type seed :: non_neg_integer()

  @doc """
  Builds a new rand32 state from a given seed.

  ## Parameters
    * `seed` - An integer seed value to initialize the generator

  ## Returns
    * A tuple representing the random number generator state
  """
  @spec build(seed()) :: rand32()
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

  @doc """
  Creates a new random integer based on the provided seed using congruential algorithm.

  ## Parameters
    * `seed` - An integer seed value to generate the random number

  ## Returns
    * A new random integer
  """
  @spec crt_rand(seed()) :: non_neg_integer()
  def crt_rand(seed) do
    Cipher.mask(214_013 * seed + 2_531_011) >>> 0
  end

  @doc """
  Generates a new random integer and returns the updated random state.

  ## Parameters
    * `rand32` - The current random number generator state

  ## Returns
    * `{new_rand32, random_value}` - Tuple containing the updated state and random integer
  """
  @spec random(rand32()) :: {rand32(), non_neg_integer()}
  def random({:rand32, s1, s2, s3}) do
    s1 = (s1 <<< 12 &&& 0xFFFFE000) |> bxor(s1 >>> 6 &&& 0x00001FFF) |> bxor(s1 >>> 19)
    s2 = (s2 <<< 4 &&& 0xFFFFFF80) |> bxor(s2 >>> 23 &&& 0x0000007F) |> bxor(s2 >>> 25)
    s3 = (s3 <<< 17 &&& 0xFFE00000) |> bxor(s3 >>> 8 &&& 0x001FFFFF) |> bxor(s3 >>> 11)

    rand32 = {:rand32, s1, s2, s3}
    rand = s1 |> bxor(s2) |> bxor(s3)
    {rand32, rand >>> 0}
  end

  @doc """
  Generates a random floating-point number between 0 and 1.

  ## Parameters
    * `rand32` - The current random number generator state

  ## Returns
    * `{new_rand32, random_value}` - Tuple containing the updated state and random float
  """
  @spec random_float(rand32()) :: {rand32(), float()}
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
