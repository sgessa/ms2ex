# `Ms2ex.Storage.Scripts`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/storage/scripts.ex#L1)

NPC / quest talk-script metadata lookups (`script:<id>` documents).

NPC scripts are keyed by npc id, quest scripts by quest id.

# `get_meta`

```elixir
@spec get_meta(integer()) :: map() | nil
```

# `quest_state`

```elixir
@spec quest_state(map() | nil, integer(), integer()) :: map() | nil
```

Finds the first state in `lower_bound..upper_bound` (matching the quest
script state-id convention: 100s accept, 200s progress, 300s complete).

# `states`

```elixir
@spec states(map() | nil) :: [map()]
```

# `states_of_type`

```elixir
@spec states_of_type(map() | nil, atom()) :: [map()]
```

Lists states of the given script-type atom (`:quest`, `:script`, `:select`,
`:job`), sorted by state id.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
