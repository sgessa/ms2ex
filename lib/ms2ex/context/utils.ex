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
end
