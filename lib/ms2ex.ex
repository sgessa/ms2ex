defmodule Ms2ex do
  def sync_ticks() do
    {res, 0} = System.cmd("awk", ["{print $1}", "/proc/uptime"])

    res
    |> String.trim()
    |> String.to_float()
    |> trunc()
  end
end
