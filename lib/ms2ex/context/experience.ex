defmodule Ms2ex.Context.Experience do
  @moduledoc """
  Context module for character experience-related operations.

  This module provides functions for managing character experience points,
  including level-ups and experience calculations.
  """

  alias Ms2ex.{Context, ProtoMetadata.ExpTable, Schema, Constants}

  @doc """
  Adds experience to a character and handles level-ups if necessary.

  If the character reaches the maximum level, no further experience is added.

  If the character gains enough experience to level up,
  the remaining experience is added to the new level.

  ## Parameters

    * `character` - The character receiving experience
    * `exp_gained` - Amount of experience to add

  ## Examples

      iex> maybe_add_exp(character, 100)
      {:ok, %Schema.Character{exp: 250}}

      iex> maybe_add_exp(level_99_character, 10000)
      {:ok, %Schema.Character{level: 100, exp: 0}}
  """
  @spec maybe_add_exp(Schema.Character.t(), non_neg_integer()) ::
          {:ok, Schema.Character.t()} | {:error, Ecto.Changeset.t()}
  def maybe_add_exp(%Schema.Character{level: level, exp: current_exp} = character, exp_gained) do
    if level >= Constants.get(:character_max_level) do
      {:ok, character}
    else
      {:ok, tnl} = ExpTable.to_next_level(level)
      total_exp = current_exp + exp_gained

      if total_exp >= tnl do
        diff = total_exp - tnl
        {:ok, character} = Context.Characters.update(character, %{level: level + 1, exp: 0})
        maybe_add_exp(character, diff)
      else
        Context.Characters.update(character, %{exp: total_exp})
      end
    end
  end
end
