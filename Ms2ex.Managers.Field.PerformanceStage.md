# `Ms2ex.Managers.Field.PerformanceStage`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/managers/field/performance_stage.ex#L1)

The Queenstown concert stage: one player (or their party) holds the stage
at a time, announced to the field as the `music_concert` field property so
clients light up the stage and show the performance timer.

The stage is released when the performer ends it, leaves the map, or the
performance runs out of time.

# `leave`

# `properties`

Active properties for a joining player, so they see a performance that
started before they entered the map.

# `release`

Releases the stage without the performer asking: the performance ran out of
time or its owner left the map.

# `stage?`

```elixir
@spec stage?(map()) :: boolean()
```

# `start`

# `stop`

Releases the stage at the performer's request; the scheduled expiry is
dropped along with it.

# `toggle_stage`

Toggles the performer between the audience floor and the stage. The client
sends a single command for both directions.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
