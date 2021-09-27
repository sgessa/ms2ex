defmodule Ms2ex.Crypto.XorCrypter do
  alias Ms2ex.Crypto.Rand32

  import Bitwise

  defstruct table: []

  @index 2

  def build(version) do
    {_rand32, rand_float} =
      version
      |> Rand32.build()
      |> Rand32.random_float()

    {_rand32, rand2_float} =
      (version * 2)
      |> Rand32.build()
      |> Rand32.random_float()

    %__MODULE__{
      table: [rand_float * 255, rand2_float * 255]
    }
  end

  def index(), do: @index

  def decrypt(%__MODULE__{} = xc, data), do: encrypt_or_decrypt(xc, data)

  def encrypt(%__MODULE__{} = xc, data), do: encrypt_or_decrypt(xc, data)

  defp encrypt_or_decrypt(xc, data) do
    Enum.reduce(0..(length(data) - 1), data, fn idx, acc ->
      table = Enum.at(xc.table, idx &&& 1)
      List.update_at(acc, idx, &bxor(&1, table))
    end)
  end
end
