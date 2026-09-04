# `Ms2ex.Context.Quests`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/context/quests.ex#L1)

Quest persistence helpers.

# `create_quest`

```elixir
@spec create_quest(map()) ::
  {:ok, Ms2ex.Schema.CharacterQuest.t()} | {:error, Ecto.Changeset.t()}
```

# `delete_quest`

```elixir
@spec delete_quest(integer(), integer(), boolean()) :: :ok
```

# `delete_quests`

```elixir
@spec delete_quests(integer(), [integer()], boolean()) :: :ok
```

Drops every persisted row of the given quests in one statement.

# `get_all_quests`

```elixir
@spec get_all_quests(integer(), integer()) :: {map(), map()}
```

# `has_completed_quest?`

```elixir
@spec has_completed_quest?(Ms2ex.Schema.Character.t(), integer()) :: boolean()
```

# `serialize_conditions`

```elixir
@spec serialize_conditions(map()) :: map()
```

# `update_quest`

```elixir
@spec update_quest(Ms2ex.Schema.CharacterQuest.t(), map()) ::
  {:ok, Ms2ex.Schema.CharacterQuest.t()} | {:error, Ecto.Changeset.t()}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
