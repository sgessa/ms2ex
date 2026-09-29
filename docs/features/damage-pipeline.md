# Damage pipeline

Status: formula aligned; a few terms and rolls still missing. Rate-based DoT
runs through the same pipeline.

## Formula

`Context.Damage.calculate`:

- attack roll = weapon + bonus attack (`min/max_weapon_atk` + `bonus_atk`),
  falling back to the job attack stat when unarmed
- skill `rate` scales it
- the target's `defense` divides it
- `resistance = (1500 - max(res - 1500 * pierce_mult, 0)) / 1500` cuts it
- crit multiplies by the `critical_damage` stat (`/100`)
- floor of 1 damage

The attack-type split (`physical` vs `magic`) picks the weapon/job attack stat
and the target's physical or magical resistance.

## DoT

`Context.Damage.calculate_rate(rate, caster, mob, physical?)` runs a dot's
`rate` through the same formula so burn effects scale with gear. The buff tick
loop adds `hp_value` + `damage_by_target_max_hp * max_hp` on top and clamps to
`current hp - 1` when `not_kill`.

## Client damage reports

The client reports landed hits back on the skill-attack packet with one of
three modes, and the server resolves each differently:

- **Target hits (0x1)** — when the attack doc carries a hit volume (box,
  cylinder, frustum or hole-cylinder), the server recomputes the targets:
  the volume is anchored at the reported impact position with the cast's
  facing, and alive mobs inside it — capped at the attack's target count —
  take the hit. Volume-less attacks (range type none) fall back to the
  client's reported live mobs. Either way the hit broadcasts the mode-1
  damage record plus the health stat record to everyone (the pair that
  makes clients draw the HP bar).
- **Point hits (0x0)** — the basic attack's swing. The client reports no
  valid target here (its actual hits arrive on the target report), so the
  server only relays the swing to other clients as a mode-0 record and
  arms the caster's battle stance.
- **Splash/region hits (0x2)** — region skills; damage rides the mode-1
  record like every other channel (see `region-splash.md`).

## Still missing

- miss / block / evade rolls
- element, range and NPC-damage bonuses
- pierce resolved with the exact client formula (still a capped share)
- SkillDamage **Tile (0x6)** record mode (tile skills) — the DotDamage (0x3)
  record is implemented and driven by the buff tick loop
