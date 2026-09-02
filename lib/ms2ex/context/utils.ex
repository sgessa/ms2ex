defmodule Ms2ex.Context.Utils do
  @moduledoc """
  Utility functions.

  This module provides common helper functions used across the application.
  """

  @doc """
  Generates a random float number between the given minimum and maximum values.

  ## Examples

      iex> rand_float(1.0, 5.0)
      3.7128453297529

      iex> rand_float(0.0, 1.0)
      0.21390374928473
  """
  @spec rand_float(float(), float()) :: float()
  def rand_float(min, max) do
    :rand.uniform() * (max - min) + min
  end

  @doc """
  Picks an entry from `entries` at random, weighted by the numeric value of
  the given key. Zero-weight entries never get picked; with no positive
  weights a plain uniform pick is used so callers don't need to guard.
  """
  @spec pick_weighted([map()], atom()) :: map()
  def pick_weighted(entries, weight_key) do
    total = Enum.reduce(entries, 0, fn entry, acc -> acc + Map.get(entry, weight_key, 0) end)

    case total do
      0 -> Enum.random(entries)
      total -> weighted_pick(entries, weight_key, total)
    end
  end

  defp weighted_pick(entries, weight_key, total) do
    pick = :rand.uniform(total)

    Enum.reduce_while(entries, 0, fn entry, acc ->
      acc = acc + Map.get(entry, weight_key, 0)

      if pick <= acc do
        {:halt, entry}
      else
        {:cont, acc}
      end
    end)
  end
end
