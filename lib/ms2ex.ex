defmodule Ms2ex do
  def generate_int() do
    <<x::signed-integer-size(32)>> = :crypto.strong_rand_bytes(4)
    x
  end

  def generate_long() do
    <<x::signed-integer-size(64)>> = :crypto.strong_rand_bytes(8)
    x
  end

  def sync_ticks() do
    {res, 0} = System.cmd("awk", ["{print $1}", "/proc/uptime"])

    res
    |> String.trim()
    |> String.to_float()
    |> trunc()
  end
end
