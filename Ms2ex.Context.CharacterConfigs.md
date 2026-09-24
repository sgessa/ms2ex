# `Ms2ex.Context.CharacterConfigs`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/context/character_configs.ex#L1)

Context module for the per-character client-config row.

Holds serialized client state — key binds, guide records, gathering
counts — that the character-config manager keeps in memory; this module
loads the row once per login and persists field updates, returning the
updated row for the manager's state.

# `get`

```elixir
@spec get(integer()) :: Ms2ex.Schema.CharacterConfig.t()
```

Returns the character's config row; a character without a row yet reads
as an all-default config.

# `update`

```elixir
@spec update(Ms2ex.Schema.CharacterConfig.t(), map()) ::
  {:ok, Ms2ex.Schema.CharacterConfig.t()} | {:error, Ecto.Changeset.t()}
```

Persists the given config values and returns the updated row. The row is
inserted when the manager's cached config has not been written yet; the
writable fields are the ones the schema changeset casts.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
