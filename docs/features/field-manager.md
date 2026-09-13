# Field manager

Status: every map instance (map + channel) runs one `Ms2ex.Managers.Field`
GenServer that owns the field's live state. The code was reorganized around
the standing architecture rules: managers own state, contexts persist,
handlers orchestrate through managers.

## Layout

`Managers.Field` is both the GenServer and the manager's API surface —
the same shape as `Managers.Character`. The process state is a plain map;
every field-object system transforms it through a state-in/state-out
submodule under `lib/ms2ex/managers/field/`:

| Submodule | Owns |
| --- | --- |
| `Field.Banner` | UGC banner slots (persistence via `Context.BannerSlots`) |
| `Field.Buff` | effect buffs: stacking, ticks, dots, removals |
| `Field.Character` | join/leave sequences, periodic stat broadcasts |
| `Field.Instrument` | instruments in play |
| `Field.InteractObject` | interact-object lifecycles (normal/reactable/hidden) |
| `Field.Item` | field drops and pickups |
| `Field.Liftable` | quest liftable props (pickup/place/expire) |
| `Field.Npc` | npc spawns, spawn cycles, damage/death, mob gates |
| `Field.Npc.Patrol` | patrol-path movement math (move_npc, follow-dummies) |
| `Field.PerformanceStage` | the concert stage |
| `Field.Portal` | portal loading |
| `Field.RegionSkill` | region skill zones and splash ticks |
| `Field.Tombstone` | dead players' tombstones |
| `Field.Trigger` | trigger-script machine runtime |
| `Field.Trigger.Conditions` | trigger condition catalog |
| `Field.Trigger.Actions` | trigger action catalog |
| `Helpers.TriggerArgs` | trigger argument coercion (int/float/bool/list/rgb/widget keys) |

Submodules never call each other's process — they receive the field state
and return the updated state. The one dependency direction to keep:
`Field.Npc` → `Field.Npc.Patrol` is one-way (Patrol is pure movement math
and never calls back into `Npc`).

## API surface

Handlers and other processes talk to the field through named functions on
`Managers.Field` (`lookup_npc/2`, `pickup_item/2`, `add_effect_buff/3`,
`enter/1`, `change_field/2..4`, ...), not raw message tuples. The generic
`call/2`/`cast/2` remain for callers that already hold the field pid, and
the manager's own handle_call/handle_info clauses stay the message
protocol. Submodule state functions are also public so tests can drive
them directly (see `field_death_test`, `trigger_runtime_test`, ...) —
tests build state maps and call the state functions or the GenServer
callbacks; they never start field processes.

## Distribution

`Managers.Field.broadcast/2` (character or topic + packet) is the single
publish path onto a field's audience; `broadcast_from/3` excludes one
process, `subscribe/1`/`unsubscribe/1` manage membership, and
`broadcast_stats/1` composes the full-vs-compact stat updates. Field
process names come from `field_name/2` (`:"field:#{map}:channel:#{ch}"`).

## Lifecycle

`enter/1` joins a character to their field, starting the process when the
map instance is not up yet (init loads portals, interact objects, banners,
liftables and trigger scripts; npc spawn docs stream in via messages so
the first trigger ticks wait for them — `spawn_docs_pending`).
`leave/1` removes a character. When the last session leaves, what
happens depends on the field: shared fields (instance 0) linger for five
minutes — a one-shot timer cancelled by the next join — before stopping,
so a player who walked out (or relogged) rejoins live state instead of a
fresh field; instanced fields stop as soon as they empty out, since a
fresh instance is allocated per entry and nothing can rejoin them.
`change_field/2..4` leaves the old field,
marks the discovered map, and pushes `RequestFieldEnter` to the client.

## Layering debt (follow-ups)

- `Context.Fishing`, `Context.Insignias`, `Context.Mastery` and
  `Context.Mobs` still call `Managers.Field` process API and broadcast
  packets. Contexts should only persist — those calls belong in handlers
  or managers when those features get reworked.
- The field state is a plain map; the full key set is documented only by
  `init/1` plus the submodule `init_*` functions. A `%Types.Field{}`
  struct would make the shape explicit (the codebase's manager-state
  convention is plain maps today, so this is a deliberate convention
  change to make later).

## Still missing

- see `trigger-runtime.md` for the trigger coverage gaps
- `Field.Trigger.Actions.set_skill/3` zones render client-side only; the
  server-side tick damage is a TODO in the action
