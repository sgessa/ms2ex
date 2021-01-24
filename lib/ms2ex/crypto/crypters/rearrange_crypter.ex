defmodule Ms2ex.Crypto.RearrangeCrypter do
  import Bitwise

  @index 1

  def build(), do: ""

  def index(), do: @index

  def decrypt(data) do
    len = length(data) >>> 1

    Enum.reduce(0..(len - 1), data, fn idx, acc ->
      swap = Enum.at(acc, idx)

      acc
      |> List.update_at(idx, fn _ -> Enum.at(acc, idx + len) end)
      |> List.update_at(idx + len, fn _ -> swap end)
    end)
  end

  def encrypt(data) do
    len = length(data) >>> 1

    Enum.reduce(0..(len - 1), data, fn idx, acc ->
      swap = Enum.at(acc, idx)

      acc
      |> List.update_at(idx, fn _ -> Enum.at(acc, idx + len) end)
      |> List.update_at(idx + len, fn _ -> swap end)
    end)
  end
end
