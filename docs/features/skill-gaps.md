# Skill gaps

Open skill-system gaps, in rough priority order.

## Player death / revive

Player death and revival are implemented (see `player-death-revive.md`).
Remaining: party/class revive skills, free-revive coupon consumption and the
daily instant-revive cap, auto-revive maps.

## Mob AI

Mobs never target players: no aggro, chase, or attack, so mob→player damage
stat broadcasts don't exist yet. `ControlNpc` streaming, boss aggro flags and
the boss target-id slot are aligned, but the NPC has no AI loop that picks a
player target and deals damage back.

## SkillDamage modes

- DotDamage (0x3): implemented — `Packets.SkillDamage.dot_damage`, driven by
  the buff tick loop (see `buff-effects.md`).
- Tile (0x6): unimplemented, tied to tile skills.

## RegionSkill rotation

`Packets.RegionSkill.add` always writes the rotation; direction-less skills
should have it zeroed.

## Skill resource costs

Regular skill casts validate and consume SP/stamina (gated on having enough,
then both drained) via `Managers.Character.Skill.cast_skill`. State skills
(recv `0x21`) do the same on cast plus a per-tick drain loop at the projected
motion `sequence_speed`, with cancellation on state change / death /
resource exhaustion (see `state-skills.md`).

## Region geometry

Regions use a fixed radius (800) instead of the exact magic-path geometry, and
the first hit always lands immediately (`ImmediateActive`/`Delay` are now
projected by the ingest but not yet consumed server-side). Repeating regions
use `splash.interval`/`fire_count`/`remove_delay`.