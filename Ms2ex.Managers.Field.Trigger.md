# `Ms2ex.Managers.Field.Trigger`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/managers/field/trigger.ex#L1)

Trigger-script runtime: every map script runs as an independent state
machine. A machine enters a state (running its on-enter actions), then
each cycle evaluates the state's conditions in document order — the
first that evaluates true runs its inline actions and transitions.

Function arguments arrive verbatim from the client data (positional
arg1..N or named); their meaning follows each function's catalog
signature.

# `drop_position`

# `guide_held?`

# `init_machines`

# `init_triggers`

# `maybe_release_guide_hold`

# `quest_state_matches?`

```elixir
@spec quest_state_matches?(map() | nil, integer()) :: boolean()
```

# `release_guide_hold`

# `skip_cutscene`

# `tick`

# `track_job`

# `track_position`

# `update_widget`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
