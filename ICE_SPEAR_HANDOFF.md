# Ice Spear buff chain — handoff note

This file is a starting point for a fresh opencode thread working on the
`feat/buff-tick-skills` branch (checked out in the worktree at
`/home/enki/Projects/maplestory2/worktrees/ms2ex-ice-spear`).

## The chain (from the data)

- Skill `10300051` (Ice Spear): attack rate `0.0`, cube magic path
  `103000511`; its first attack condition skill carries the splash.
- The client's AoE damage packet (`SubCommand.CubeMagicPath`) spawns the
  region, which fires the **splash skill `10300052`** (rate 1.74, up to 8
  targets) once over mobs near the cast position.
- `10300052` applies on damage: `10300051` (chill) + `10300182` (marker).
- `10300051` **chill**: `max_count 6`, 3s, `MovementSpeed:-0.15`,
  `MountSpeed:-0.15`, `skills: [10300052@1]` fired when it hits its stack
  cap. Stacks via the trigger's `Condition.OverlapCount` (projected as
  `overlap_count`).
- `10300052` **frozen**: 1s, `stun 3`, `category Stunned`,
  `update.cancel: [10300051]` (cancels the chill). This is what should freeze
  the mob (client-derived; no server stun packet is sent).
- `10300182` **marker**: 10s, `modify_overlap: [{id: 10300271, offset: 1}]`.
- `10300271`: `max_count 10`, 20s, `interval 1000`, ice DOT
  (`rate 0.93`, magic/ice), `skills: [10300275@1, 10300272@1]` fired at 10
  stacks. `10300275`/`10300272` each apply `10300273`.

## What's implemented (commits `cca868d`, `544c223` on this branch)

- **Buff stacking via `overlap_count`**: re-applying an effect adds its
  trigger's `Condition.OverlapCount` stacks while refreshing the window
  (`UpdateEndTime`), so the chill stacks to 6 and fires the frozen.
- **`update.cancel`**: applying the frozen cancels the chill; cancellations
  bypass the expiry reschedule (`remove_buff(..., force: true)`).
- **`modify_overlap`**: a buff bumps another effect's stacks on apply
  (clamps, fires the target's skills at the cap, removes at 0).
- **Splash regions**: regions repeat at `interval` for `fire_count` hits
  (`fire_count <= 0` fires once); `ImmediateActive`/`Delay` not projected so
  the first hit always lands immediately.
- **`has_splash` skip**: on-hit effects skip splash-carrying skills (region
  skills, not direct buffs) so the frozen isn't applied by the `@target`
  path every hit.
- `Packets.Buff` gained a buff-field `:update` mode (command 2 + `BuffFlag`
  int + fields) used when stacking.

## Outstanding

1. **`10300271` is never applied** by the splash (it only applies
   `10300051` + `10300182`), so `modify_overlap` has no target — the ice DOT
   and the 10-stack fire never happen. Find where the reference applies
   `10300271`: check other Ice Spear motions/levels, the level condition
   skills, or a related skill that shares the ice combo. The reference
   `ApplyEffect` passes `stacks: effect.Condition.OverlapCount`, and
   `ModifyBuffStackCount` bumps `modifyOverlapCount.Id` on fresh application.
2. The full DoT pipeline (element/attack-type rolls) and the buff `skills`
   firing on combat events are still deferred (see
   `docs/reference-deltas.md`).

## Files

- `lib/ms2ex/managers/field/buff.ex` — apply/stack/cancel/modify_overlap.
- `lib/ms2ex/managers/field.ex` — region/splash hits, `apply_skill_effects`.
- `lib/ms2ex/types/buff.ex` — buff struct, `stacks`, `max_stacks`, `cancel`.
- `lib/ms2ex/types/skill_cast.ex` — `attack_skills`, `splash_skill_cast`.
- `lib/ms2ex/packets/game/buff.ex` — add/remove/update modes.
- `lib/ms2ex/handlers/game/skill.ex` — `@splash` (CubeMagicPath) handler.
- ingest `src/Projection/SkillProjection.cs`, `AdditionalEffectProjection.cs`
  (committed `017b07c` on ingest `master`) — needs a rebuild + re-ingest for
  `overlap_count`, `modify_overlap`, `has_splash`, `fire_count` to populate.

## Verify

- `mise exec -- mix test` (53 passing).
- Stacking simulation (needs Redis + `start_game_servers: false`):
  apply `10300051` with `overlap_count 1` six times → stacks 1→6 → the frozen
  (`10300052`) fires and cancels the chill.