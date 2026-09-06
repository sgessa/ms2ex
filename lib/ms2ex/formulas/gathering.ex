defmodule Ms2ex.Formulas.Gathering do
  @moduledoc """
  Gathering success rate, ported from the client's
  `calcGatheringObjectSuccessRate`.

  A node is a guaranteed hit until it was harvested `high_rate_limit_count`
  times; past that the rate falls off quadratically until it reaches zero.
  Harvesting in someone else's home cuts both limits to a fifth.
  """

  @spec success_rate(non_neg_integer(), integer(), integer(), boolean()) :: float()
  def success_rate(current_count, high_rate_limit, normal_rate_limit, own_home? \\ true) do
    {high_rate_limit, normal_rate_limit} =
      if own_home? do
        {high_rate_limit, normal_rate_limit}
      else
        {trunc(high_rate_limit * 0.2), trunc(normal_rate_limit * 0.2)}
      end

    if current_count < high_rate_limit do
      100.0
    else
      max(falloff(current_count, high_rate_limit, normal_rate_limit), 0.0)
    end
  end

  defp falloff(current_count, high_rate_limit, normal_rate_limit) do
    base = (normal_rate_limit / 0.9 * 0.3 - 0.5) / 1.406
    scale = (base * 3 * 2 - base) / 2

    if scale == 0.0 do
      0.0
    else
      factor = 1 / (scale * scale) / 0.7111
      over = current_count - high_rate_limit

      (1 - factor * over * over) * 100
    end
  end
end
