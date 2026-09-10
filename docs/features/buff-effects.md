# Buffs, effects, dots, recovery

Status: buff tick loop, stacking, cancel-on-apply, recovery and DoT are
implemented. Remaining gaps are listed at the bottom.

## Entry points

- `add_buff` — a skill's effect applies a buff to the caster
  (`Managers.Field.Buff.add_buff`), synchronous inside `cast_skill`.
- `add_effect_buff` — an effect applied directly (recovery consumables, dot
  chains, tick skills).
- `add_mob_buff` — an on-hit effect applied to a field npc (e.g. a burn).

`effect_available?` gates on the effect existing in metadata. Re-applying an
effect stacks it up to `property.max_count` and refreshes its window.

## Recovery

`add_effect_buff` items (rare) apply an effect buff directly. Buffs with a
`recovery` property restore HP/SP/EP using
`value + rate_of_max + heal_per_magical_atk` (crit multiplier unless disabled),
broadcast a targeted stat update plus a `SkillDamage.heal` record. The effect
projection emits `recovery`.

The common potion path is an item-skill: item → use-skill
(`skill_id`/`skill_level`) → skill `consume.use_item` (+ `meso`, `hp_rate`);
the skill-use handler reads the item uid, applies the skill's buff/recovery,
and consumes the item (e.g. item 20000022 → skill 90000032 → effect 90000032
→ `recovery.hp_value=200`). `UseItem` itself has no item-skill case.

## Buff lifecycle

Buffs expire: `add_buff`/`add_effect_buff` schedule `{:remove_buff, id}` at
`end_tick`; the field fetches the buff, reverses any stat modifiers, broadcasts
the remove packet and stops the buff agent. `remove_buff` reschedules when the
buff was refreshed since its timer was set, so re-applied debuffs don't expire
mid-chain. `Types.Buff.set_shield_health` guards effects without a shield.

Buff stat modification: `Types.Buff.stat_modifiers` combines `status.values`
(flat) with `status.rates` (percentage of the current max) into per-stat deltas
applied to the owner's stat maxes on buff add and reversed on remove.

## Tick loop

A buff whose effect has `recovery`, `dot` or `tick_skills` schedules
`{:buff_tick, id}` at `delay_tick + interval_tick` (interval 0 defaults to
`duration_tick + 1000`, the "proc once" sentinel). Each proc:

- applies the full recovery value (`recovery_amounts`, no split across ticks)
- applies `dot.damage`: `hp_value + damage_by_target_max_hp * max_hp`,
  `not_kill` clamps to current hp - 1; `sp_value`/`ep_value` drain;
  `recover_hp_by_damage` heals the caster (positive heal rather than a negated
  HpAmount add)
- chains `dot.buff` (target 0 = caster / 1 = owner) via `add_effect_buff`
- re-applies each `tick_skill` (conditionSkill/splashSkill with
  `activeByIntervalTick`) as a buff on the owner — e.g. Ice Bomb's effect ticks
  10300263@2 every second.

DoT damage is rate-based: non-const dots run the damage formula with the dot's
`rate` against the caster's attack and the target's stats, then add `hp_value`
+ `damage_by_target_max_hp * max_hp`. After the last proc the buff is removed
at `end_tick`. Non-ticking buffs (stat-only) skip the loop and just expire.
Mob-owned dots are applied through the field's own damage path (tagging the
caster as dealer) and broadcast as `SkillDamage.dot_damage` (mode 0x3).

## On-hit skill effects

The skill's attack `conditionSkill`s (both plain and `dependOnDamageCount`,
i.e. `skills_on_damage`) are applied to each mob that takes a hit, except
effects that carry a splash (`has_splash`) — those are region skills spawned
by the region system, not direct buffs (this keeps Ice Spear's frozen 10300052
from cancelling the chill on every hit). Flame Wave's burn: skill 10300021 →
effect 10300021 (fire, `dot.damage` rate 0.21, 1s interval / 10s duration)
buffs the target.

## Stacking, cancel, overlap

Buffs are tracked per owner+effect+caster in the field (`state.buffs`).
Re-applying stacks up to `property.max_count`; at the cap the buff fires its
`skills` (e.g. Ice Spear's chill 10300051 stacks to 6 → applies frozen
10300052). A buff's `update.cancel` removes the listed effects from the owner
on apply (frozen cancels the chill), honouring `check_same_caster`. Re-applying
refreshes the window and adds the trigger's `overlap_count` stacks;
`modify_overlap` effects additionally bump the target effect's stacks on fresh
application (splash marker 10300182 / Ice Bomb marker 10300265 both modify the
frost 10300271, while the chill stacks via its own `overlap_count` up to 6).
Frost lands via skill 10300271 "Hurricane Warning" (wizard ice combo) whose
attack skills apply `10300271@N`+`10300276@1`+`10300272@1` on the `@target`
hit. `property.type`/`category`/`stun` are projected so the client renders the
debuff/stun (the client derives the frozen animation from the buff; no
server-side stun state is sent). `update.reset_cooldown` clears the listed
cooldowns and pushes a `SkillCooldown` record.

## Remaining gaps

1. `status.special_values` / `status.special_rates` (special attributes like
   damage-type multipliers): metadata is projected, and item-granted special
   stats are applied to the character's stat metadata, but **buff-granted**
   ones are not — `stat_modifiers` only folds `status.values`/`status.rates`.
2. The full DoT damage pipeline (attack type/element/grade, crit/miss/block
   rolls) is skipped — DoT uses the shared formula but as normal damage with no
   crit roll.
3. `ApplyCancel` is unimplemented.
4. The effect's `skills` (non-tick condition skills) only fire on reaching max
   stacks here; the full model fires them on combat events
   (OnHit/OnAttacked/OnDeath...). The max-stack firing is required for the Ice
   Spear chill→frozen chain.
5. Conditions and immune-category checks are not evaluated.
6. Recovery on mob-owned buffs is skipped; an empty effect is still applied as
   a no-op buff.