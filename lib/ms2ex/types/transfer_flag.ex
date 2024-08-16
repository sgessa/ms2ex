defmodule Ms2ex.TransferFlags do
  import Bitwise

  @flags %{
    none: 0,
    splittable: 2,
    tradeable: 4,
    bind: 8,
    limit_trade: 16
  }

  def set(flags) when is_list(flags) do
    flags
    |> Enum.map(&flag(&1))
    |> Enum.reduce(nil, fn
      flag, nil -> flag
      flag, flags -> flags ||| flag
    end)
  end

  def has_flag?(flags, flag_name) do
    (flags &&& flag(flag_name)) != 0
  end

  defp flag(flag_name), do: Map.get(@flags, flag_name)
end
