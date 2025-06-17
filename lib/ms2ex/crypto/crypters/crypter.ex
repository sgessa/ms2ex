defmodule Ms2ex.Crypto.Crypter do
  @moduledoc """
  Base module for crypter implementations providing common functionality.

  This module defines utilities used by the concrete crypter implementations.
  """

  @doc """
  Calculates the index for a crypter based on the protocol version.

  ## Parameters
    * `version` - Protocol version
    * `index` - Base index value for the crypter

  ## Returns
    * Calculated index for the crypter in the sequence
  """
  @spec get_index(non_neg_integer(), non_neg_integer()) :: non_neg_integer()
  def get_index(version, index) do
    rem(version + index, 3) + 1
  end
end
