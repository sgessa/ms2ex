# `Ms2ex.Managers.Field.Trigger`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/managers/field/trigger.ex#L1)

Trigger-script runtime: every map script runs as an independent state
machine. A machine enters a state (running its on-enter actions), then
each cycle evaluates the state's conditions in document order — the
first that evaluates true runs its inline actions and transitions.

The condition and action catalogs live in `Trigger.Conditions` and
`Trigger.Actions`.

# `box_contains?`

Whether a position is inside a trigger box; boxes grow by 10 units on
every axis to compensate for entity size.

# `drop_position`

# `guide_held?`

# `init_machines`

# `init_triggers`

# `maybe_release_guide_hold`

# `release_guide_hold`

# `skip_cutscene`

# `tick`

# `track_job`

# `track_position`

# `update_widget`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
