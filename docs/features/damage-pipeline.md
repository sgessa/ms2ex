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

## Still missing

- miss / block / evade rolls
- element, range and NPC-damage bonuses
- pierce resolved with the exact client formula (still a capped share)
- SkillDamage **Tile (0x6)** record mode (tile skills) — the DotDamage (0x3)
  record is implemented and driven by the buff tick loop
