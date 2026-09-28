# Damage formula

Status: formula aligned; a few terms and rolls still missing. DoT is now
rate-based through the same pipeline.

## Pipeline

`Context.Damage.calculate` implements the pipeline:

- The damage record resolves per relayed hit: the cast's motion point and
  the client-relayed attack point index into the level doc's motions and
  attacks, so a multi-attack skill (e.g. two Energy Bolt projectiles)
  applies each projectile's own rate/value. Out-of-range client indices
  fall back to the motion's first attack; skills without attack docs
  resolve to zero (the 1-damage floor stands in).
- The attack roll is the weapon + bonus attack
  (`min/max_weapon_atk` + `bonus_atk`), falling back to the job attack stat
  when unarmed.
- Skill `rate` scales it.
- The target's `defense` divides it, through the same defense divisor the
  client derives from the caster's piercing stat (`1 - min(0.3,
  piercing/1000 - 1)`; an unset piercing stat doubles the divisor).
- `resistance = (1500 - max(res - 1500 * pierce_mult, 0)) / 1500` cuts it.
- Crit multiplies by the `critical_damage` stat (`1 + crit/1000`, clamped
  to 2.5).
- A floor of 1 damage applies.

The attack-type split (`physical` vs `magic`) picks the weapon/job attack stat
and the target's physical or magical resistance.

## Mob hits

`Context.Damage.calculate_mob_hit` mirrors the same pipeline for a mob's
swing against a character: the mob's physical attack and the swing's
damage rate drive the hit, cut down by the character's defense and
physical resistance. Mobs carry no piercing stat, so the defense divisor
doubles — halving the hit — exactly as the client formula derives from the
unset stat.

## DoT

`Context.Damage.calculate_rate(rate, caster, mob, physical?)` runs a dot's
`rate` through the same formula, so burn effects scale with gear. The buff
tick loop adds `hp_value` + `damage_by_target_max_hp * max_hp` on top and
clamps to `current hp - 1` when `not_kill`.

## Divergences (still open)

- `damage.value` (flat skill damage): now projected by the ingest and applied
  via `SkillCast.damage_value/1` — no longer a gap.
- element / range / npc-damage bonuses: skipped.
- miss / block / evade rolls: skipped.
- DoT ticks share the missing attack type/element/grade and crit/miss/block
  rolls; they always run as normal damage with no crit roll.

## History

With the old hardcoded 1M attack base every hit outdamaged even raid bosses.
That base is gone; the formula now runs on the real weapon/attack stats.