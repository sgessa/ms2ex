# `Ms2ex.Context.CharacterConfigs`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/context/character_configs.ex#L1)

Context module for the per-character client-config row.

Holds serialized client state — key binds, guide records, gathering
counts — that the character-config manager keeps in memory; this module
creates the row together with the character, loads it once per login and
persists field updates, returning the updated row for the manager's state.

# `create`

```elixir
@spec create(Ms2ex.Schema.Character.t()) ::
  {:ok, Ms2ex.Schema.CharacterConfig.t()} | {:error, Ecto.Changeset.t()}
```

Creates the config row of a character. Runs inside character creation so
every character carries exactly one row for its whole life.

# `get`

```elixir
@spec get(integer()) :: Ms2ex.Schema.CharacterConfig.t()
```

Returns the character's config row. The row is created together with the
character, so a missing row is a data bug and raises.

# `update`

```elixir
@spec update(Ms2ex.Schema.CharacterConfig.t(), map()) ::
  {:ok, Ms2ex.Schema.CharacterConfig.t()} | {:error, Ecto.Changeset.t()}
```

Persists the given config values and returns the updated row; the
writable fields are the ones the schema changeset casts.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
