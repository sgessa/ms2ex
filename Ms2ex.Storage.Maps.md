# `Ms2ex.Storage.Maps`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/storage/maps.ex#L1)

# `get_bounds`

# `get_field_spawn`

```elixir
@spec get_field_spawn(integer()) :: map()
```

Spawn point to drop a player onto when they enter a field. Entering flush
with the floor drops the player through it, so the arrival sits above the
spawn point and falls the short distance.

# `get_interact_objects`

# `get_meta`

# `get_mob_spawns`

# `get_npc_spawns`

# `get_portals`

# `get_property`

# `get_revival_return_id`

# `get_spawn`

One of the map's enabled spawn points, picked at random. Respawns use it
directly (the player is placed on the exact coordinate); field entry
builds on it (see `get_field_spawn/1`) so the player drops in from above.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
