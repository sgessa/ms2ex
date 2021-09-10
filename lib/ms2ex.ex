defmodule Ms2ex do
  def generate_id() do
    floor(:rand.uniform() * floor(:math.pow(2, 31)))
  end

  def sync_ticks() do
    {res, 0} = System.cmd("awk", ["{print $1}", "/proc/uptime"])

    res
    |> String.trim()
    |> String.to_float()
    |> trunc()
  end
end
