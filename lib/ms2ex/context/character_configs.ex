defmodule Ms2ex.Context.CharacterConfigs do
  @moduledoc """
  Context module for the per-character client-config row.

  Holds serialized client state — key binds, guide records, gathering
  counts — that the character-config manager keeps in memory; this module
  creates the row together with the character, loads it once per login and
  persists field updates, returning the updated row for the manager's state.
  """

  alias Ms2ex.Repo
  alias Ms2ex.Schema

  @doc """
  Creates the config row of a character. Runs inside character creation so
  every character carries exactly one row for its whole life.
  """
  @spec create(Schema.Character.t()) ::
          {:ok, Schema.CharacterConfig.t()} | {:error, Ecto.Changeset.t()}
  def create(%Schema.Character{id: character_id}) do
    Repo.insert(%Schema.CharacterConfig{character_id: character_id})
  end

  @doc """
  Returns the character's config row. The row is created together with the
  character, so a missing row is a data bug and raises.
  """
  @spec get(integer()) :: Schema.CharacterConfig.t()
  def get(character_id), do: Repo.get_by!(Schema.CharacterConfig, character_id: character_id)

  @doc """
  Persists the given config values and returns the updated row; the
  writable fields are the ones the schema changeset casts.
  """
  @spec update(Schema.CharacterConfig.t(), map()) ::
          {:ok, Schema.CharacterConfig.t()} | {:error, Ecto.Changeset.t()}
  def update(%Schema.CharacterConfig{} = config, attrs) do
    config
    |> Schema.CharacterConfig.changeset(attrs)
    |> Repo.update()
  end
end
