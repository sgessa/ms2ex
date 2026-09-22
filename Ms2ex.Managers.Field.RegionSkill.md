# `Ms2ex.Managers.Field.RegionSkill`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/managers/field/region_skill.ex#L1)

# `add`

# `apply_splash`

# `fire_trigger_zone`

Fires a trigger skill zone: applies the attack to whoever stands inside
(damage, then the skill's effect as a buff) and expires the zone once its
fire count runs out.

# `load_cube_zones`

Map cubes carrying a skill zone (boost/slow lanes, hazard water). Cube
zones are not announced to clients — the lane visuals are map decor —
the field ticks them and applies the zone skill's effect to players
standing inside.

# `load_zones`

Map-placed skill zones (heal towers, aura pads): perpetual client-side
zones at a fixed position. Each zone gets a stable source id for the field
session; entering players receive the zone add frame — that frame is only
the visual, so the field ticks the zone on its own interval and applies
the skill to players standing inside (the Healing Forest's recovery
towers heal through this).

# `maybe_tick`

# `remove_trigger_zones`

Removes every active trigger skill zone spawned for the trigger id.

# `send_zones`

Sends the field's map-placed skill zones to an entering player.

# `spawn_trigger_zone`

Spawns the trigger skill zone for the trigger id: a one-shot zone that
fires `count` times at the fixed interval, announced to clients so they
render the effect (the falling rocks).

# `tick_cube_zones`

Applies each cube-skill zone's attack to the players standing inside:
the zone's damage rule, then its effect as a buff (e.g. the boost lanes'
movement-speed bonus). Re-applying while inside refreshes the effect
window; the short effect duration expires it shortly after stepping off.

# `tick_placed_zone`

Fires a placed region zone on its own interval: applies the zone skill to
every player standing inside (the tower's HP recovery rides the skill's
effect buff) and reschedules the next fire. Placed zones are perpetual —
they live as long as the field does. An interval-less zone fires once.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
