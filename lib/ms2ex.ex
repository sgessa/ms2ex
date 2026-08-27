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

  # monotonic ms since the app was compiled, so client-facing tick values stay
  # positive (the OTP clock base itself can be negative, which clients read as
  # "already expired" after the int32 truncation on the wire)
  @sync_base System.monotonic_time(:millisecond)

  def sync_ticks() do
    System.monotonic_time(:millisecond) - @sync_base
  end

  def get_env({:system, env}), do: System.get_env(env)
  def get_env(val), do: val
end
