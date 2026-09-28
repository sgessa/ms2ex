# `Ms2ex.Managers.Field.Npc`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/managers/field/npc.ex#L1)

# `advance_projectiles`

# `apply_projectile_impact`

Applies an aimed (lookAtType 1) projectile's damage when its flight
time elapses: the client chases the shot onto its victim, so the damage
follows the timer. The shot lands while its victim is still on the
field, live-synced, and inside the firing attack's reach of the launch
point. (Fixed-line shots are simulated per tick instead — see
advance_projectiles/2.)

# `apply_skill_effects`

# `apply_skill_explosion`

# `damage`

# `despawn`

# `expire_emote`

```elixir
@spec expire_emote(Ms2ex.Types.FieldNpc.t(), integer()) :: Ms2ex.Types.FieldNpc.t()
```

Expires a finished scripted emotion: once the emote's playback window
elapses the npc falls back to its idle sequence and flags itself dirty
so the next control broadcast carries the revert.

# `finish_carry`

# `launch_direction`

# `load_mob_spawns`

# `load_npc`

# `load_npc_spawns`

# `load_spawn`

# `remove_npc`

# `spawn_follow_dummy`

# `spawn_npc`

# `tick`

# `trigger_spawn`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
