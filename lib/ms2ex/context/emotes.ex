defmodule Ms2ex.Context.Emotes do
  @moduledoc """
  Context module for character emote-related operations.

  This module provides functions for listing, learning, and accessing
  default emotes available to characters.
  """

  alias Ms2ex.{Repo, Schema}

  import Ecto.Query, except: [update: 2]

  @default_emotes [
    90_200_011,
    90_200_004,
    90_200_024,
    90_200_041,
    90_200_042
  ]

  @doc """
  Lists all emote IDs that a character has learned.

  ## Examples

      iex> list(character)
      [90200011, 90200004, 90200024, 90200041, 90200042]
  """
  @spec list(Schema.Character.t()) :: [integer()]
  def list(%Schema.Character{id: character_id}) do
    Schema.Emote
    |> where([e], e.character_id == ^character_id)
    |> select([e], e.emote_id)
    |> Repo.all()
  end

  @doc """
  Makes a character learn a new emote by ID.

  ## Examples

      iex> learn(character, 90200011)
      {:ok, %Schema.Emote{}}

      iex> learn(character, 90200011) # when already learned
      {:error, %Ecto.Changeset{}}
  """
  @spec learn(Schema.Character.t(), integer()) ::
          {:ok, Schema.Emote.t()} | {:error, Ecto.Changeset.t()}
  def learn(%Schema.Character{} = character, emote_id) do
    character
    |> Ecto.build_assoc(:emotes)
    |> Schema.Emote.changeset(%{emote_id: emote_id})
    |> Repo.insert()
  end

  @doc """
  Returns the list of default emote IDs available to all characters.

  ## Examples

      iex> default_emotes()
      [90200011, 90200004, 90200024, 90200041, 90200042]
  """
  @spec default_emotes() :: [integer()]
  def default_emotes(), do: @default_emotes
end
