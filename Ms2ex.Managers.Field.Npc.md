# `Ms2ex.Managers.Field.Npc`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/managers/field/npc.ex#L1)

# `apply_skill_effects`

# `damage`

# `despawn`

# `expire_emote`

```elixir
@spec expire_emote(Ms2ex.Types.FieldNpc.t(), integer()) :: Ms2ex.Types.FieldNpc.t()
```

Expires a finished scripted emotion: once the emote's playback window
elapses the npc falls back to its idle sequence and flags itself dirty
so the next control broadcast carries the revert.

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
