defmodule Ms2ex.Crypto.TableCrypter do
  alias Ms2ex.Crypto.Rand32

  defstruct encrypted: [], decrypted: []

  @index 3
  @table_size 256

  def build(version) do
    {encrypted, _rand32} =
      0..(@table_size - 1)
      |> Enum.into([])
      |> shuffle(version)

    decrypted = List.duplicate(nil, @table_size)

    decrypted =
      Enum.reduce(0..(@table_size - 1), decrypted, fn idx, acc ->
        enc_idx = Enum.at(encrypted, idx)
        List.update_at(acc, enc_idx, fn _ -> idx end)
      end)

    %__MODULE__{encrypted: encrypted, decrypted: decrypted}
  end

  def index(), do: @index

  def decrypt(%__MODULE__{} = tc, data) do
    Enum.map(data, fn x ->
      Enum.at(tc.decrypted, x)
    end)

    # |> IO.inspect(base: :hex, label: "DEC TABLE")
  end

  def encrypt(%__MODULE__{} = tc, data) do
    Enum.map(data, fn x ->
      Enum.at(tc.encrypted, x)
    end)

    # |> IO.inspect(base: :hex, label: "ENC TABLE")
  end

  defp shuffle(data, version) do
    seed =
      version
      |> :math.pow(2)
      |> trunc()

    rand32 = Rand32.build(seed)

    Enum.reduce((@table_size - 1)..0, {data, rand32}, fn idx, {data, rand32} ->
      {rand32, rand} = Rand32.random(rand32)

      rand_idx = rem(rand, idx + 1)

      swap = Enum.at(data, idx)
      rand = Enum.at(data, rand_idx)

      data =
        data
        |> List.update_at(idx, fn _ -> rand end)
        |> List.update_at(rand_idx, fn _ -> swap end)

      {data, rand32}
    end)
  end
end
