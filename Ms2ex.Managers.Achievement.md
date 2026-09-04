# `Ms2ex.Managers.Achievement`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/managers/achievement.ex#L1)

# `call`

# `cast`

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `claim_reward`

Claims every pending reward grade up to the current grade.

# `flush`

Persists every pending achievement update.

# `load`

Sends the achievement initialize and load packets, batched per
60 entries.

# `start`

# `stop`

# `toggle_favorite`

# `trophy_counts`

Trophy counts per category: [combat, adventure, lifestyle].

# `update`

Advances every achievement whose active grade condition matches the
event. Fire-and-forget: progress is applied asynchronously.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
