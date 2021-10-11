defmodule Ms2ex do
  def generate_int() do
    <<x::signed-integer-size(32)>> = :crypto.strong_rand_bytes(4)
    x
  end

  def generate_long() do
    <<x::signed-integer-size(64)>> = :crypto.strong_rand_bytes(8)
    x
  end

  def generate_id() do
    <<x::integer-size(32)>> = :crypto.strong_rand_bytes(4)
    x
  end

  # Calculate probability
  def roll(chance_pct) do
    chance_pct <= 0 + 100 * :rand.uniform()
  end

  def sync_ticks() do
    {res, 0} = System.cmd("awk", ["{print $1}", "/proc/uptime"])

    res
    |> String.trim()
    |> String.to_float()
    |> trunc()
  end

  def get_env({:system, env}), do: System.get_env(env)
  def get_env(val), do: val
end
