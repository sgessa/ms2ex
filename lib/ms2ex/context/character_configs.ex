defmodule Ms2ex.Context.CharacterConfigs do
  @moduledoc """
  Context module for the per-character client-config row.

  Holds serialized client state — key binds, guide records, gathering
  counts — that the character-config manager keeps in memory; this module
  loads the row once per login and persists field updates, returning the
  updated row for the manager's state.
  """

  alias Ms2ex.Repo
  alias Ms2ex.Schema

  @doc """
  Returns the character's config row; a character without a row yet reads
  as an all-default config.
  """
  @spec get(integer()) :: Schema.CharacterConfig.t()
  def get(character_id) do
    Repo.get_by(Schema.CharacterConfig, character_id: character_id) ||
      %Schema.CharacterConfig{character_id: character_id}
  end

  @doc """
  Persists the given config values and returns the updated row. The row is
  inserted when the manager's cached config has not been written yet; the
  writable fields are the ones the schema changeset casts.
  """
  @spec update(Schema.CharacterConfig.t(), map()) ::
          {:ok, Schema.CharacterConfig.t()} | {:error, Ecto.Changeset.t()}
  def update(%Schema.CharacterConfig{} = config, attrs) do
    config
    |> Schema.CharacterConfig.changeset(attrs)
    |> Repo.insert_or_update()
  end

end
