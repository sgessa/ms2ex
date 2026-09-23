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

  @config_fields [:key_binds, :guide_records, :instant_revive_count]

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
  Upserts the character's harvest counters in a single statement; the row
  need not exist yet.
  """
  @spec update_gathering_counts(integer(), map()) :: :ok
  def update_gathering_counts(character_id, counts) do
    %Schema.CharacterConfig{character_id: character_id, gathering_counts: counts}
    |> Repo.insert(
      on_conflict: {:replace, [:gathering_counts, :updated_at]},
      conflict_target: :character_id
    )
    |> then(fn {:ok, _} -> :ok end)
  end

  @doc """
  Persists one config field and returns the updated row. The row is
  inserted when the manager's cached config has not been written yet.
  """
  @spec update_field(Schema.CharacterConfig.t(), atom(), term()) ::
          {:ok, Schema.CharacterConfig.t()} | {:error, Ecto.Changeset.t()}
  def update_field(%Schema.CharacterConfig{id: nil, character_id: character_id}, field, value)
      when field in @config_fields do
    %Schema.CharacterConfig{character_id: character_id}
    |> Ecto.Changeset.change(%{field => value})
    |> Repo.insert()
  end

  def update_field(%Schema.CharacterConfig{} = config, field, value)
      when field in @config_fields do
    config
    |> Ecto.Changeset.change(%{field => value})
    |> Repo.update()
  end

end
